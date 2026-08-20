locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = var.environment == "dev"
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.common_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${local.name_prefix}-eks"
  cluster_version = var.cluster_version

  enable_cluster_creator_admin_permissions = false

  access_entries = merge({
    cluster_creator = {
      principal_arn = var.cluster_creator_admin_principal_arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    }, {
    for principal_arn in var.cluster_admin_principal_arns : principal_arn => {
      principal_arn = principal_arn
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  })

  kms_key_administrators = [var.cluster_creator_admin_principal_arn]

  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_endpoint_private_access      = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      desired_size   = var.node_desired_size
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      iam_role_additional_policies = {
        ebs_csi = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }

  cluster_addons = {
    coredns            = {}
    kube-proxy         = {}
    vpc-cni            = {}
    aws-ebs-csi-driver = { most_recent = true }
  }

  tags = local.common_tags
}

data "aws_iam_policy_document" "external_secrets_read" {
  statement {
    sid    = "AllowReadSecretsManager"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = concat(var.external_secrets_allowed_secret_arns, [aws_db_instance.banking.master_user_secret[0].secret_arn])
  }

  statement {
    sid       = "AllowDecryptRDSManagedSecret"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.database.arn]
  }
}

resource "aws_iam_policy" "external_secrets_read" {
  name        = "${local.name_prefix}-external-secrets-read"
  description = "Read-only access for External Secrets Operator"
  policy      = data.aws_iam_policy_document.external_secrets_read.json

  tags = local.common_tags
}

module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name_prefix}-external-secrets-irsa"

  role_policy_arns = {
    secrets_read = aws_iam_policy.external_secrets_read.arn
  }

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${var.external_secrets_sa_namespace}:${var.external_secrets_sa_name}"]
    }
  }

  tags = local.common_tags
}

module "aws_load_balancer_controller_irsa" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-role-for-service-accounts-eks?ref=c29ec1ed409683086f63f83ff5b10a6f3c296ef2"

  role_name = "${local.name_prefix}-aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    this = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "kube-system:aws-load-balancer-controller"
      ]
    }
  }

  tags = local.common_tags
}

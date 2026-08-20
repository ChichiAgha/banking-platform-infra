data "aws_iam_policy_document" "terraform_state_key" {
  statement {
    sid    = "AllowAccountKeyAdministration"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
}

resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for banking Terraform state"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.terraform_state_key.json
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/${var.project}-terraform-state"
  target_key_id = aws_kms_key.terraform_state.key_id
}

resource "aws_s3_bucket" "terraform_state" {
  bucket        = "${var.project}-${data.aws_caller_identity.current.account_id}-terraform-state"
  force_destroy = var.force_destroy_state_buckets
}

resource "aws_s3_bucket" "terraform_state_logs" {
  bucket        = "${var.project}-${data.aws_caller_identity.current.account_id}-terraform-state-logs"
  force_destroy = var.force_destroy_state_buckets
}

resource "aws_s3_bucket_public_access_block" "terraform_state_logs" {
  bucket                  = aws_s3_bucket.terraform_state_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id
  rule {
    id     = "expire-access-logs"
    status = "Enabled"
    filter {}
    expiration { days = 365 }
  }
}

data "aws_iam_policy_document" "terraform_state_logs" {
  statement {
    sid       = "AllowS3LogDelivery"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.terraform_state_logs.arn}/state-access/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.terraform_state.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.terraform_state_logs.arn, "${aws_s3_bucket.terraform_state_logs.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id
  policy = data.aws_iam_policy_document.terraform_state_logs.json
}

resource "aws_s3_bucket_logging" "terraform_state" {
  bucket        = aws_s3_bucket.terraform_state.id
  target_bucket = aws_s3_bucket.terraform_state_logs.id
  target_prefix = "state-access/"
  depends_on    = [aws_s3_bucket_policy.terraform_state_logs]
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.terraform_state.arn, "${aws_s3_bucket.terraform_state.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

locals {
  infra_repository_prefix = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_infra_repository}@${var.github_infra_repository_id}"
  infra_plan_subjects = [
    "${local.infra_repository_prefix}:pull_request",
    "${local.infra_repository_prefix}:ref:refs/heads/main",
  ]
  infra_apply_subjects = [
    "${local.infra_repository_prefix}:environment:development",
    "${local.infra_repository_prefix}:environment:production",
  ]
}

data "aws_iam_policy_document" "github_infra_plan_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.infra_plan_subjects
    }
  }
}

data "aws_iam_policy_document" "github_infra_apply_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.infra_apply_subjects
    }
  }
}

resource "aws_iam_role" "github_terraform_plan" {
  name                 = "${var.project}-github-terraform-plan"
  assume_role_policy   = data.aws_iam_policy_document.github_infra_plan_assume.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "github_terraform_plan_read_only" {
  role       = aws_iam_role.github_terraform_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role" "github_terraform_apply" {
  name                 = "${var.project}-github-terraform-apply"
  assume_role_policy   = data.aws_iam_policy_document.github_infra_apply_assume.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "terraform_state_access" {
  statement {
    sid       = "ListStatePrefix"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.terraform_state.arn]
  }
  statement {
    sid     = "ManageStateAndLocks"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "${aws_s3_bucket.terraform_state.arn}/banking/*",
      "${aws_s3_bucket.terraform_state.arn}/banking/*.tflock",
    ]
  }
  statement {
    sid       = "UseStateEncryptionKey"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [aws_kms_key.terraform_state.arn]
  }
}

resource "aws_iam_role_policy" "github_terraform_plan_state" {
  name   = "${var.project}-terraform-state"
  role   = aws_iam_role.github_terraform_plan.id
  policy = data.aws_iam_policy_document.terraform_state_access.json
}

resource "aws_iam_role_policy" "github_terraform_apply_state" {
  name   = "${var.project}-terraform-state"
  role   = aws_iam_role.github_terraform_apply.id
  policy = data.aws_iam_policy_document.terraform_state_access.json
}

data "aws_iam_policy_document" "terraform_apply" {
  statement {
    sid    = "ManageDevelopmentPlatform"
    effect = "Allow"
    actions = [
      "autoscaling:*", "ec2:*", "eks:*", "elasticloadbalancing:*",
      "acm:*",
      "iam:*", "kms:*", "logs:*", "rds:*",
      "cognito-idp:CreateUserPool", "cognito-idp:DeleteUserPool",
      "cognito-idp:DescribeUserPool", "cognito-idp:UpdateUserPool",
      "cognito-idp:CreateUserPoolClient", "cognito-idp:DeleteUserPoolClient",
      "cognito-idp:DescribeUserPoolClient", "cognito-idp:UpdateUserPoolClient",
      "cognito-idp:CreateUserPoolDomain", "cognito-idp:DeleteUserPoolDomain",
      "cognito-idp:DescribeUserPoolDomain", "cognito-idp:UpdateUserPoolDomain",
      "cognito-idp:GetUserPoolMfaConfig", "cognito-idp:SetUserPoolMfaConfig",
      "cognito-idp:ListTagsForResource", "cognito-idp:TagResource",
      "cognito-idp:UntagResource", "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret", "secretsmanager:DescribeSecret",
      "secretsmanager:RotateSecret", "secretsmanager:TagResource",
      "secretsmanager:UpdateSecret", "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_terraform_apply" {
  name   = "${var.project}-terraform-apply"
  role   = aws_iam_role.github_terraform_apply.id
  policy = data.aws_iam_policy_document.terraform_apply.json
}
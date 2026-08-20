aws_region   = "us-east-1"
environment  = "prod"
project      = "banking"

vpc_cidr = "10.30.0.0/16"
azs      = ["us-east-1a", "us-east-1b", "us-east-1c"]

public_subnets  = ["10.30.0.0/24", "10.30.1.0/24", "10.30.2.0/24"]
private_subnets = ["10.30.10.0/24", "10.30.11.0/24", "10.30.12.0/24"]

cluster_version      = "1.30"
node_instance_types  = ["m6i.large"]
node_desired_size    = 3
node_min_size        = 3
node_max_size        = 9

external_secrets_sa_namespace = "external-secrets"
external_secrets_sa_name      = "external-secrets"

external_secrets_allowed_secret_arns = [
  "arn:aws:secretsmanager:us-east-1:123456789012:secret:/bank/prod/app-*"
]

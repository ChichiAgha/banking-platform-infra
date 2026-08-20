aws_region  = "eu-west-2"
environment = "dev"
project     = "banking"

vpc_cidr = "10.20.0.0/16"
azs      = ["eu-west-2a", "eu-west-2b"]

public_subnets  = ["10.20.0.0/24", "10.20.1.0/24"]
private_subnets = ["10.20.10.0/24", "10.20.11.0/24"]

cluster_version     = "1.35"
node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_min_size       = 1
node_max_size       = 3

external_secrets_sa_namespace = "external-secrets"
external_secrets_sa_name      = "external-secrets"

external_secrets_allowed_secret_arns = [
  "arn:aws:secretsmanager:eu-west-2:716969407191:secret:/bank/dev/app-*"
]

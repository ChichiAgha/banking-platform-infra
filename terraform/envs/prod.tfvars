aws_region  = "eu-west-2"
environment = "prod"
project     = "banking"

vpc_cidr = "10.30.0.0/16"
azs      = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]

public_subnets  = ["10.30.0.0/24", "10.30.1.0/24", "10.30.2.0/24"]
private_subnets = ["10.30.10.0/24", "10.30.11.0/24", "10.30.12.0/24"]

cluster_version                      = "1.35"
cluster_endpoint_public_access       = false
cluster_endpoint_public_access_cidrs = []
cluster_admin_principal_arns         = ["arn:aws:iam::716969407191:user/chinow"]
cluster_creator_admin_principal_arn  = "arn:aws:iam::716969407191:role/banking-github-terraform-apply"
node_instance_types                  = ["m6i.large"]
node_desired_size                    = 3
node_min_size                        = 3
node_max_size                        = 9

external_secrets_sa_namespace = "external-secrets"
external_secrets_sa_name      = "external-secrets"

external_secrets_allowed_secret_arns = []

db_instance_class        = "db.t4g.small"
db_allocated_storage     = 100
db_max_allocated_storage = 500
db_multi_az              = true
db_backup_retention_days = 35
db_deletion_protection   = true
db_skip_final_snapshot   = false
application_domain       = "bank.creativity-is-wealth.co.uk"

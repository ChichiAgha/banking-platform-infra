output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN used for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "external_secrets_irsa_role_arn" {
  description = "IAM role ARN to annotate on External Secrets service account"
  value       = module.external_secrets_irsa.iam_role_arn
}

output "rds_endpoint" {
  description = "PostgreSQL endpoint; not sensitive"
  value       = aws_db_instance.banking.address
}

output "rds_port" {
  description = "PostgreSQL port"
  value       = aws_db_instance.banking.port
}

output "rds_database_name" {
  description = "Initial PostgreSQL database name"
  value       = aws_db_instance.banking.db_name
}

output "rds_master_secret_arn" {
  description = "AWS-managed Secrets Manager ARN for the RDS credentials"
  value       = aws_db_instance.banking.master_user_secret[0].secret_arn
}

output "aws_load_balancer_controller_irsa_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller service account"
  value       = module.aws_load_balancer_controller_irsa.iam_role_arn
}

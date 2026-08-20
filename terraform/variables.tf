variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
}

variable "project" {
  description = "Project identifier"
  type        = string
  default     = "banking"
}

variable "vpc_cidr" {
  description = "VPC CIDR range"
  type        = string
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDRs"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDRs"
  type        = list(string)
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS API endpoint is reachable from approved public CIDRs"
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs permitted to reach the public EKS API endpoint; use explicit /32 addresses for temporary administration"
  type        = list(string)
  default     = []

  validation {
    condition     = length([for cidr in var.cluster_endpoint_public_access_cidrs : cidr if cidr == "0.0.0.0/0"]) == 0
    error_message = "Public EKS API access must never allow 0.0.0.0/0."
  }
}

variable "cluster_creator_admin_principal_arn" {
  description = "Stable IAM principal used by Terraform CI/CD to administer EKS and its KMS key"
  type        = string
}

variable "cluster_admin_principal_arns" {
  description = "IAM principals granted explicit EKS cluster-administrator access"
  type        = set(string)
  default     = []
}

variable "node_instance_types" {
  description = "Managed node group instance types"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum nodes"
  type        = number
  default     = 4
}

variable "external_secrets_sa_namespace" {
  description = "Namespace for External Secrets service account"
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_sa_name" {
  description = "Service account name for External Secrets"
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_allowed_secret_arns" {
  description = "Secrets Manager ARNs External Secrets can read"
  type        = list(string)
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "18.3"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "db_name" {
  description = "Initial application database name"
  type        = string
  default     = "bankingdb"
}

variable "db_master_username" {
  description = "RDS master username; password is generated and managed by RDS"
  type        = string
  default     = "banking_admin"
}

variable "db_allocated_storage" {
  description = "Initial RDS storage in GiB"
  type        = number
}

variable "db_max_allocated_storage" {
  description = "Maximum autoscaled RDS storage in GiB"
  type        = number
}

variable "db_multi_az" {
  description = "Whether RDS uses a Multi-AZ standby"
  type        = bool
}

variable "db_backup_retention_days" {
  description = "RDS automated backup retention period"
  type        = number
}

variable "db_deletion_protection" {
  description = "Protect RDS from deletion"
  type        = bool
}

variable "db_skip_final_snapshot" {
  description = "Whether RDS deletion skips a final snapshot"
  type        = bool
}

variable "application_domain" {
  description = "Public application hostname used for Cognito callback and logout URLs"
  type        = string
}

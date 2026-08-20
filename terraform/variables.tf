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

variable "aws_region" {
  description = "AWS region containing the shared application registry"
  type        = string
}

variable "project" {
  description = "Project identifier"
  type        = string
  default     = "banking"
}

variable "github_owner" {
  description = "GitHub organization or user that owns the application repository"
  type        = string
}

variable "github_repository" {
  description = "GitHub application repository name, without the owner"
  type        = string
}

variable "github_branch" {
  description = "Only this branch may assume the ECR publishing role"
  type        = string
  default     = "main"
}

variable "force_delete_ecr" {
  description = "Permit Terraform to delete non-empty repositories; keep false outside disposable sandboxes"
  type        = bool
  default     = false
}

variable "force_destroy_state_buckets" {
  description = "Permit deletion of versioned Terraform state buckets during an explicitly approved full teardown"
  type        = bool
  default     = false
}

variable "image_retention_count" {
  description = "Number of tagged images retained per repository"
  type        = number
  default     = 50
}

variable "github_owner_id" {
  description = "Immutable numeric GitHub owner ID used in OIDC subjects"
  type        = string
}

variable "github_repository_id" {
  description = "Immutable numeric GitHub repository ID used in OIDC subjects"
  type        = string
}

variable "github_infra_repository" {
  description = "GitHub infrastructure repository name, without the owner"
  type        = string
}

variable "github_infra_repository_id" {
  description = "Immutable numeric GitHub infrastructure repository ID"
  type        = string
}
output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  value = var.aws_region
}

output "ecr_registry" {
  value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "ecr_repository_urls" {
  value = { for name, repository in aws_ecr_repository.service : name => repository.repository_url }
}

output "github_ecr_publish_role_arn" {
  value = aws_iam_role.github_ecr_publish.arn
}

output "github_oidc_subject" {
  value = local.github_subject
}

output "terraform_state_bucket" {
  value = aws_s3_bucket.terraform_state.id
}

output "terraform_state_kms_key_arn" {
  value = aws_kms_key.terraform_state.arn
}

output "github_terraform_plan_role_arn" {
  value = aws_iam_role.github_terraform_plan.arn
}

output "github_terraform_apply_role_arn" {
  value = aws_iam_role.github_terraform_apply.arn
}
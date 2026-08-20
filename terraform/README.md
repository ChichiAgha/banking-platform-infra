# Terraform: AWS platform infrastructure

This stack provisions AWS networking, EKS, managed nodes, and External Secrets IAM.

## Delivery model

GitHub Actions uses short-lived AWS credentials through OIDC:

- Pull requests run formatting, validation, TFLint, Trivy IaC scanning, and a read-only development plan.
- Merges to main start the development apply workflow.
- The apply job uses the protected development environment and requires approval before AWS changes begin.
- A weekly refresh-only plan fails if infrastructure drift is detected.
- No long-lived AWS access keys are stored in GitHub.

Application delivery remains GitOps: Terraform creates the platform; Argo CD reconciles Kubernetes manifests from the GitOps repository.

## Remote state

State is stored in the versioned, public-access-blocked S3 bucket banking-716969407191-terraform-state, encrypted by a customer-managed KMS key. Native S3 lockfiles protect concurrent operations.

- Bootstrap key: banking/bootstrap/terraform.tfstate
- Development key: banking/dev/terraform.tfstate
- Production should use a separate key and protected environment.

Provider lock files are committed so CI and local runs use the same provider versions. The account-specific bootstrap tfvars file remains ignored.

## Workflows

- terraform-ci.yaml: PR quality gates and development plan artifact.
- terraform-cd.yaml: protected development plan and apply after merge.
- terraform-drift.yaml: scheduled development drift detection.

Trivy reports HIGH and CRITICAL findings, while only CRITICAL findings block. The managed-node egress exception in .trivyignore.yaml is documented and expires on 2026-09-30. It must be removed or reviewed after private AWS service VPC endpoints are implemented.

## Local validation

    terraform -chdir=terraform fmt -check -recursive
    terraform -chdir=terraform init -backend=false
    terraform -chdir=terraform validate
    terraform -chdir=terraform plan -var-file=envs/dev.tfvars

Do not run a local apply for normal changes. Submit a feature branch and pull request, review the plan artifact, merge it, then approve the protected environment deployment.

## Security notes

- The EKS API endpoint is private only.
- Nodes run in private subnets and currently use NAT for required outbound access.
- External Secrets is restricted to the configured Secrets Manager ARN scope.
- Development and production values are separated under envs/.
- The apply IAM policy is service-scoped but broad for initial provisioning. Narrow it with resource conditions and an organizational permission boundary before treating this as a production landing zone.

The terraform/bootstrap stack owns the state bucket, KMS key, GitHub OIDC integration, ECR repositories, and CI roles. Bootstrap should be changed rarely, by an administrator, with its own plan review.

The development EKS stack has been planned but not applied. Merging the infrastructure pull request does not bypass protected-environment approval.

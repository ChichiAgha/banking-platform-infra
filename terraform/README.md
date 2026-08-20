# Terraform: EKS + IRSA + External Secrets IAM

This stack provisions:
- AWS VPC and networking
- EKS cluster and managed node group
- IAM policy for reading AWS Secrets Manager
- IRSA role for External Secrets service account

## Files

- `main.tf`: VPC, EKS, IAM policy, IRSA role
- `variables.tf`: input variables
- `outputs.tf`: exported values
- `envs/dev.tfvars`: dev environment inputs
- `envs/prod.tfvars`: prod environment inputs

## Prerequisites

- Terraform >= 1.6
- AWS credentials with permissions for VPC, EKS, IAM
- EKS kubectl access after apply

## Apply (dev)

```bash
cd infrastructure/terraform
terraform init
terraform plan -var-file=envs/dev.tfvars
terraform apply -var-file=envs/dev.tfvars
```

## Apply (prod)

```bash
cd infrastructure/terraform
terraform init
terraform plan -var-file=envs/prod.tfvars
terraform apply -var-file=envs/prod.tfvars
```

## External Secrets wiring

After apply, get the IRSA role:

```bash
terraform output external_secrets_irsa_role_arn
```

Annotate the External Secrets service account with this role ARN, or configure it via Helm values.

Service account target defaults:
- Namespace: `external-secrets`
- Name: `external-secrets`

Adjust in tfvars if your deployment uses different names.

## Important

- Replace placeholder AWS account IDs in tfvars ARNs.
- Keep dev/prod state isolated in your backend config.
- Use private subnets for workloads and keep least-privilege secret ARNs.

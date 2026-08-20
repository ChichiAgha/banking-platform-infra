# One-time AWS image-publishing bootstrap

This root creates four immutable ECR repositories and a least-privilege IAM role that only the configured GitHub repository and branch can assume through OIDC.

## Run

```bash
cd infrastructure/terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars first.
terraform init
terraform fmt -check
terraform validate
terraform plan -out bootstrap.tfplan
terraform apply bootstrap.tfplan
terraform output
```

Do not commit `terraform.tfvars` or Terraform state. Configure the resulting values as GitHub repository variables:

- `AWS_REGION`
- `AWS_ECR_PUBLISH_ROLE_ARN`
- `ECR_REGISTRY`
- `GITOPS_REPOSITORY` (for example `techbleat/banking-gitops`)

If the GitHub OIDC provider already exists in the AWS account, import it before planning:

```bash
terraform import aws_iam_openid_connect_provider.github \
  arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
```

The trust policy is restricted to the exact `owner/repository` and `main` branch subject. Protect that branch in GitHub.

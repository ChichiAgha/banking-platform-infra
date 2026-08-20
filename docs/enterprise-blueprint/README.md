# Enterprise EKS Blueprint (3-Repo Model)

This blueprint defines a production-grade repository and delivery model for:
- EKS (AWS)
- Terraform (platform infrastructure)
- Helm + GitOps (application deployment)
- AWS Secrets Manager + External Secrets + IRSA (secret delivery)

## 1) Repository Model

### Repo A: `bank-platform-aws-infra`
Purpose: Provision and manage AWS platform infrastructure.

Owns:
- VPC, subnets, route tables, NAT, security groups
- EKS cluster, managed node groups
- IAM OIDC provider and IRSA roles
- ECR repositories
- AWS Load Balancer Controller prerequisites
- External Secrets IAM policies and roles
- Optional Route53 and ACM setup

Suggested layout:

```text
bank-platform-aws-infra/
  modules/
    vpc/
    eks/
    iam-irsa/
    ecr/
    route53-acm/
  envs/
    dev/
      main.tf
      variables.tf
      outputs.tf
      backend.hcl
    prod/
      main.tf
      variables.tf
      outputs.tf
      backend.hcl
  global/
    providers.tf
    versions.tf
  .github/workflows/
    terraform-plan-apply.yml
```

### Repo B: `bank-microservices-app`
Purpose: Build, test, and publish application artifacts.

Owns:
- Service source code (user, transaction, activity)
- Frontend source code
- Dockerfiles (including frontend multistage build)
- Unit/integration tests
- Security scans and SBOM generation

Suggested layout:

```text
bank-microservices-app/
  services/
    user-service/
    transaction-service/
    activity-service/
  frontend/
  shared/
  scripts/
  .github/workflows/
    app-ci-build-publish.yml
```

### Repo C: `bank-eks-gitops`
Purpose: Declare desired cluster state and promote releases.

Owns:
- Helm charts
- Environment values (dev/prod)
- ExternalSecret resources
- Ingress, autoscaling, and policy manifests

Suggested layout:

```text
bank-eks-gitops/
  charts/
    banking-app/
      Chart.yaml
      templates/
      values.yaml
  env/
    dev/
      values.yaml
      externalsecrets.yaml
      kustomization.yaml
    prod/
      values.yaml
      externalsecrets.yaml
      kustomization.yaml
  clusters/
    dev/
      apps.yaml
    prod/
      apps.yaml
  .github/workflows/
    promote-image.yml
```

## 2) Branching and Promotion Strategy

Use trunk-based development with controlled promotion.

### Common rules
- `main` is protected in all repos.
- Short-lived feature branches from `main`.
- PR reviews required.
- Status checks required.

### Repo A (Platform)
- PR to `main` runs `terraform plan`.
- Merge to `main` may auto-apply for `dev` with approval gates.
- `prod` apply always manual approval.

### Repo B (Application)
- PR to `main`: lint, test, build, scan.
- Merge to `main`: publish immutable image tags (git SHA) + signatures + SBOM.
- No direct cluster deployment from this repo.

### Repo C (GitOps)
- Dev promotion PR updates `env/dev/values.yaml` image digests.
- Prod promotion PR copies same digest into `env/prod/values.yaml`.
- Argo CD/Flux syncs changes to clusters.

## 3) CI/CD Stages

1. Developer opens PR in Repo B.
2. CI validates code, tests, scans.
3. Merge builds and pushes signed images to ECR.
4. Pipeline opens PR in Repo C to bump `dev` image digests.
5. Merge triggers GitOps sync to dev.
6. Run smoke tests in dev.
7. Open Repo C PR to promote same digest to prod.
8. Manual approval and sync to prod.
9. Progressive rollout (canary or rolling) and health checks.
10. Auto-rollback if health checks fail.

## 4) Secret Delivery (AWS Secrets Manager)

Use AWS Secrets Manager as source of truth.

Pattern:
- Secret paths:
  - `/bank/dev/app`
  - `/bank/prod/app`
- External Secrets Operator reads AWS secrets.
- IRSA restricts each service account to least-privilege secret paths.
- No plaintext secrets in git or Helm values.

## 5) Environment Contract

### Required (runtime)
- `DATABASE_URL`
- `KAFKA_BOOTSTRAP_SERVERS`
- `FRONTEND_ORIGIN`
- `SPRING_DATASOURCE_URL`
- `SPRING_DATASOURCE_USERNAME`
- `SPRING_DATASOURCE_PASSWORD`
- `REDIS_HOST`
- `REDIS_PORT`

### Policy
- No localhost values in production manifests.
- Avoid fallback defaults for critical dependencies in production.
- Use immutable image references (digest preferred).

## 6) Ingress Model (EKS)

Two valid choices:
- AWS Load Balancer Controller (ALB-backed Ingress)
- NGINX Ingress Controller (in-cluster NGINX)

Recommendation for interview-ready AWS-native architecture:
- ALB-backed Ingress + path/host routing in Ingress manifests.

## 7) What to Say in Interviews (2-minute summary)

- "I separated concerns into 3 repos: Terraform platform, app build repo, and GitOps deployment repo."
- "We use EKS with ALB-backed Ingress, Helm manifests, and GitOps for deterministic promotion."
- "Images are built once, signed, scanned, and promoted by digest from dev to prod."
- "Secrets never live in git; they come from AWS Secrets Manager through External Secrets with IRSA."
- "This gave us traceable deployments, blast-radius control, and enterprise-grade change governance."

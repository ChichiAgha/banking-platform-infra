#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-}" == "DESTROY-EVERYTHING" ]] || { echo "Usage: $0 DESTROY-EVERYTHING" >&2; exit 2; }
for command in aws terraform; do command -v "$command" >/dev/null || { echo "Missing: $command" >&2; exit 1; }; done
for variable in AWS_REGION STATE_BUCKET STATE_KMS_KEY_ARN; do [[ -n "${!variable:-}" ]] || { echo "Unset: $variable" >&2; exit 1; }; done

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bootstrap_tfvars="$repository_root/terraform/bootstrap/terraform.tfvars"
[[ -f "$bootstrap_tfvars" ]] || { echo "Missing ignored file: $bootstrap_tfvars" >&2; exit 1; }

account_id="$(aws sts get-caller-identity --query Account --output text)"
caller_arn="$(aws sts get-caller-identity --query Arn --output text)"
echo "AWS account: $account_id"
echo "Caller: $caller_arn"
read -r -p "Type DESTROY-$account_id to continue: " account_confirmation
[[ "$account_confirmation" == "DESTROY-$account_id" ]] || { echo "Cancelled." >&2; exit 1; }

backup_directory="${TEARDOWN_BACKUP_DIR:-$repository_root/teardown-backup-$account_id}"
mkdir -p "$backup_directory"
chmod 700 "$backup_directory"
echo "Sensitive state backup: $backup_directory"

terraform -chdir="$repository_root/terraform" init -reconfigure \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="key=banking/dev/terraform.tfstate" \
  -backend-config="region=$AWS_REGION" \
  -backend-config="encrypt=true" \
  -backend-config="kms_key_id=$STATE_KMS_KEY_ARN" \
  -backend-config="use_lockfile=true"
terraform -chdir="$repository_root/terraform" state pull > "$backup_directory/development.tfstate"
chmod 600 "$backup_directory/development.tfstate"

if [[ "${CLEAN_KUBERNETES:-true}" == "true" ]] && command -v kubectl >/dev/null; then
  cluster_name="$(terraform -chdir="$repository_root/terraform" output -raw cluster_name 2>/dev/null || true)"
  if [[ -n "$cluster_name" ]]; then
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$cluster_name"
    kubectl delete applications.argoproj.io --all -n argocd --timeout=10m 2>/dev/null || true
    kubectl delete ingress --all --all-namespaces --timeout=10m 2>/dev/null || true
    kubectl delete service --all --all-namespaces --field-selector spec.type=LoadBalancer --timeout=10m 2>/dev/null || true
  fi
fi

terraform -chdir="$repository_root/terraform" plan -destroy -lock-timeout=5m \
  -var-file=envs/dev.tfvars -out="$backup_directory/development-destroy.tfplan"
terraform -chdir="$repository_root/terraform" show -no-color \
  "$backup_directory/development-destroy.tfplan" > "$backup_directory/development-destroy-plan.txt"
read -r -p "Review the plan, then type APPLY-DEVELOPMENT-DESTROY: " development_confirmation
[[ "$development_confirmation" == "APPLY-DEVELOPMENT-DESTROY" ]] || { echo "Cancelled." >&2; exit 1; }
terraform -chdir="$repository_root/terraform" apply -lock-timeout=5m -auto-approve \
  "$backup_directory/development-destroy.tfplan"

terraform -chdir="$repository_root/terraform/bootstrap" init -reconfigure \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="key=banking/bootstrap/terraform.tfstate" \
  -backend-config="region=$AWS_REGION" \
  -backend-config="encrypt=true" \
  -backend-config="kms_key_id=$STATE_KMS_KEY_ARN" \
  -backend-config="use_lockfile=true"
terraform -chdir="$repository_root/terraform/bootstrap" state pull > "$backup_directory/bootstrap.tfstate"
chmod 600 "$backup_directory/bootstrap.tfstate"

bootstrap_work_directory="$(mktemp -d)"
trap 'rm -rf -- "$bootstrap_work_directory"' EXIT
cp "$repository_root"/terraform/bootstrap/*.tf "$bootstrap_work_directory/"
cp "$repository_root/terraform/bootstrap/.terraform.lock.hcl" "$bootstrap_work_directory/"
cp "$bootstrap_tfvars" "$bootstrap_work_directory/terraform.tfvars"
sed -i '/backend "s3" {}/d' "$bootstrap_work_directory/versions.tf"
cp "$backup_directory/bootstrap.tfstate" "$bootstrap_work_directory/terraform.tfstate"

terraform -chdir="$bootstrap_work_directory" init -backend=false
terraform -chdir="$bootstrap_work_directory" plan -destroy \
  -var-file=terraform.tfvars \
  -var=force_delete_ecr=true \
  -var=force_destroy_state_buckets=true \
  -out=bootstrap-destroy.tfplan
terraform -chdir="$bootstrap_work_directory" show -no-color bootstrap-destroy.tfplan \
  > "$backup_directory/bootstrap-destroy-plan.txt"
read -r -p "Review the plan, then type DESTROY-BOOTSTRAP-$account_id: " bootstrap_confirmation
[[ "$bootstrap_confirmation" == "DESTROY-BOOTSTRAP-$account_id" ]] || { echo "Bootstrap retained; development is already destroyed." >&2; exit 1; }
terraform -chdir="$bootstrap_work_directory" apply -auto-approve bootstrap-destroy.tfplan
cp "$bootstrap_work_directory/terraform.tfstate" "$backup_directory/bootstrap-destroyed.tfstate"
chmod 600 "$backup_directory/bootstrap-destroyed.tfstate"

echo "Teardown completed. KMS deletion remains scheduled for AWS's waiting period."
echo "Resources still tagged Project=banking:"
aws resourcegroupstaggingapi get-resources --region "$AWS_REGION" \
  --tag-filters Key=Project,Values=banking \
  --query 'ResourceTagMappingList[].ResourceARN' --output table
echo "Retain until verified: $backup_directory"

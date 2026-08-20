#!/usr/bin/env bash
set -euo pipefail

terraform_dir="${1:-terraform}"
output_file="${2:-production-handoff.yaml}"

outputs="$(terraform -chdir="${terraform_dir}" output -json)"

rds_endpoint="$(jq -r '.rds_endpoint.value' <<<"${outputs}")"
rds_port="$(jq -r '.rds_port.value' <<<"${outputs}")"
rds_secret_arn="$(jq -r '.rds_master_secret_arn.value' <<<"${outputs}")"
certificate_arn="$(jq -r '.acm_certificate_arn.value' <<<"${outputs}")"
user_pool_arn="$(jq -r '.cognito_user_pool_arn.value' <<<"${outputs}")"
user_pool_client_id="$(jq -r '.cognito_user_pool_client_id.value' <<<"${outputs}")"
user_pool_domain="$(jq -r '.cognito_user_pool_domain.value' <<<"${outputs}")"
vpc_id="$(jq -r '.vpc_id.value' <<<"${outputs}")"

cognito_json="$(jq -cn \
  --arg pool "${user_pool_arn}" \
  --arg client "${user_pool_client_id}" \
  --arg domain "${user_pool_domain}" \
  '{userPoolARN:$pool,userPoolClientID:$client,userPoolDomain:$domain}')"

{
  printf 'externalSecrets:\n'
  printf '  awsSecretPath: %s\n' "${rds_secret_arn}"
  printf '  databaseHost: %s\n' "${rds_endpoint}"
  printf '  databasePort: "%s"\n' "${rds_port}"
  printf 'ingress:\n'
  printf '  annotations:\n'
  printf '    alb.ingress.kubernetes.io/certificate-arn: %s\n' "${certificate_arn}"
  printf "    alb.ingress.kubernetes.io/auth-idp-cognito: '%s'\n" "${cognito_json}"
  printf 'platform:\n'
  printf '  vpcId: %s\n' "${vpc_id}"
} >"${output_file}"

printf 'Created non-secret production handoff: %s\n' "${output_file}"

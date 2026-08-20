#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./bootstrap_split_repos.sh /home/s10golden/raw_banking/BankingApp /home/s10golden/raw_banking/split-repos
#
# Result:
#   - banking-platform-infra (Terraform only)
#   - banking-app (backend + frontend app code)
#   - banking-gitops (Helm + Argo/GitOps manifests)

SRC_ROOT="${1:-/home/s10golden/raw_banking/BankingApp}"
DEST_ROOT="${2:-/home/s10golden/raw_banking/split-repos}"

APP_REPO="${DEST_ROOT}/banking-app"
INFRA_REPO="${DEST_ROOT}/banking-platform-infra"
GITOPS_REPO="${DEST_ROOT}/banking-gitops"

if [[ ! -d "${SRC_ROOT}" ]]; then
  echo "Source root not found: ${SRC_ROOT}" >&2
  exit 1
fi

mkdir -p "${APP_REPO}" "${INFRA_REPO}" "${GITOPS_REPO}"

# Clean current contents so reruns are deterministic.
find "${APP_REPO}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
find "${INFRA_REPO}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
find "${GITOPS_REPO}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

# 1) App repo: service source + frontend source.
cp -r "${SRC_ROOT}/techbleat-global-bank-backend" "${APP_REPO}/"
cp -r "${SRC_ROOT}/techbleat-global-bank-frontend" "${APP_REPO}/"

if [[ -f "${SRC_ROOT}/README.md" ]]; then
  cp "${SRC_ROOT}/README.md" "${APP_REPO}/"
fi
if [[ -f "${SRC_ROOT}/architectural-diagram.html" ]]; then
  cp "${SRC_ROOT}/architectural-diagram.html" "${APP_REPO}/"
fi
if [[ -f "${SRC_ROOT}/architectural-diagram.png" ]]; then
  cp "${SRC_ROOT}/architectural-diagram.png" "${APP_REPO}/"
fi

# Remove deployment-only materials from app repo to keep responsibility clean.
rm -rf "${APP_REPO}/techbleat-global-bank-backend/docker-compose.yml" || true

# 2) Infra repo: Terraform only.
cp -r "${SRC_ROOT}/infrastructure/terraform" "${INFRA_REPO}/"

# 3) GitOps repo: Helm chart + Argo CD starter and promotion workflows.
mkdir -p "${GITOPS_REPO}/deploy/helm"
cp -r "${SRC_ROOT}/deploy/helm/banking-app" "${GITOPS_REPO}/deploy/helm/"
cp -r "${SRC_ROOT}/gitops-repo-starter/." "${GITOPS_REPO}/"

# Add convenience README files.
cat > "${APP_REPO}/REPO_SCOPE.md" << 'EOF'
# Repository Scope

This repository contains application source code only:
- Backend services
- Frontend application

It does not own Terraform platform infrastructure or GitOps environment manifests.
EOF

cat > "${INFRA_REPO}/REPO_SCOPE.md" << 'EOF'
# Repository Scope

This repository contains Terraform platform infrastructure only:
- EKS
- Networking
- IAM/IRSA
- External Secrets IAM policy/role
EOF

cat > "${GITOPS_REPO}/REPO_SCOPE.md" << 'EOF'
# Repository Scope

This repository contains deployment-state configuration only:
- Helm chart values per environment
- Argo CD application manifests
- Promotion workflow for immutable image tags
EOF

printf "\nCreated split repositories:\n"
printf -- "- %s\n" "${APP_REPO}"
printf -- "- %s\n" "${INFRA_REPO}"
printf -- "- %s\n" "${GITOPS_REPO}"

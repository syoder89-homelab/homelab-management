#!/bin/sh

# Bootstrap ArgoCD
#
# Deploys a minimal ArgoCD installation. After bootstrap, ArgoCD
# will self-manage its own configuration via the management-root Application.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARGOCD_DIR="${SCRIPT_DIR}/../applications/argocd"
helm dependency update "${ARGOCD_DIR}"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm template -n argocd argocd "${ARGOCD_DIR}" \
  --values "${ARGOCD_DIR}/config/envs/prod/service.yaml" \
  | kubectl apply -f -

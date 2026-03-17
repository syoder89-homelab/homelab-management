#!/bin/sh

# Apply root ArgoCD Applications and AppProjects
#
# These are the "App of Apps" entry points that wire ArgoCD to
# watch all three GitOps repos:
#   - homelab-management (this repo)
#   - homelab-infra (cross-cluster infrastructure)
#   - homelab-apps (workload applications)

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
kubectl apply -f "${SCRIPT_DIR}/manifests/"

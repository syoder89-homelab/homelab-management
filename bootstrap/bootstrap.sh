#!/bin/sh

# Bootstrap the management cluster (Scorpius)
#
# This script runs the bootstrap steps in dependency order:
# 1. 1Password Connect — secrets provider (chicken-and-egg: requires `op` CLI)
# 2. cert-manager — TLS certificates (required by Kargo webhooks)
# 3. ArgoCD — GitOps continuous deployment
# 4. Root Applications — ArgoCD Applications + AppProjects for all repos
# 5. Kargo — progressive delivery platform
#
# Prerequisites:
#   - kubectl configured for the target cluster
#   - `op` CLI authenticated (1Password)
#   - `helm` v3.10+
#   - `htpasswd` (from apache2-utils)
#
# Usage:
#   cd bootstrap/
#   ./bootstrap.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Step 1: 1Password Connect ==="
"${SCRIPT_DIR}/01-onepassword-connect.sh"

echo "=== Step 2: cert-manager ==="
"${SCRIPT_DIR}/02-cert-manager.sh"

echo "=== Step 3: ArgoCD ==="
"${SCRIPT_DIR}/03-argocd.sh"

echo "=== Step 4: Root Applications ==="
"${SCRIPT_DIR}/04-apply-root-apps.sh"

echo "=== Step 5: Kargo ==="
"${SCRIPT_DIR}/05-kargo.sh"

echo "=== Bootstrap complete ==="
echo "ArgoCD and Kargo are now self-managing from the homelab-management repo."
echo "The management-root Application will sync all management apps via GitOps."

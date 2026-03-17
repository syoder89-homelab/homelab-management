#!/bin/sh

# Bootstrap 1Password Connect Operator
#
# This MUST run before ArgoCD because other apps depend on
# OnePasswordItem CRDs to pull secrets from 1Password vaults.
#
# This step cannot be GitOps-driven (chicken-and-egg: the secrets
# provider needs secrets to exist before it can provide them).

set -eu

APP_DIR="$(cd "$(dirname "$0")" && pwd)/charts/onepassword-connect"
helm dependency update "${APP_DIR}"

# Fetch credentials from 1Password vault
# Chart 2.3.0+ mounts credentials as a file — store raw JSON, not base64-encoded
op_json="$(op document get --vault homelab "Scorpius Credentials File" --format json)"
op_token="$(op item get --vault homelab "Scorpius Access Token: Scorpius" --fields credential --reveal)"

kubectl create namespace onepassword-connect --dry-run=client -o yaml | kubectl apply -f -
kubectl -n onepassword-connect create secret generic op-credentials \
  --from-literal=1password-credentials.json="$op_json" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n onepassword-connect create secret generic onepassword-token \
  --from-literal=token="$op_token" \
  --dry-run=client -o yaml | kubectl apply -f -

helm template -n onepassword-connect onepassword-connect "${APP_DIR}" \
  --values "${APP_DIR}/values.yaml" --include-crds \
  | kubectl apply -f -

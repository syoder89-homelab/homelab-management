#!/bin/sh

# Bootstrap Kargo
#
# Deploys Kargo with a generated admin password and signing key.
# After bootstrap, Kargo will be managed via the management-root
# Application and self-manage its own config.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KARGO_DIR="${SCRIPT_DIR}/../applications/kargo"
helm dependency update "${KARGO_DIR}"

pass=$(openssl rand -base64 48 | tr -d "=+/" | head -c 32)
hashed_pass=$(htpasswd -bnBC 10 "" "$pass" | tr -d ':\n')
signing_key=$(openssl rand -base64 48 | tr -d "=+/" | head -c 32)
password_file=$(mktemp "${TMPDIR:-/tmp}/kargo-admin-password.XXXXXX")
values_file=$(mktemp "${TMPDIR:-/tmp}/kargo-bootstrap-values.XXXXXX")

umask 077
printf '%s\n' "$pass" > "$password_file"
cat > "$values_file" <<EOF
kargo:
  api:
    adminAccount:
      passwordHash: "$hashed_pass"
      tokenSigningKey: "$signing_key"
EOF

cleanup() {
  rm -f "$values_file"
}

trap cleanup EXIT INT TERM

printf 'Kargo admin password written to %s\n' "$password_file" >&2

kubectl create namespace kargo --dry-run=client -o yaml | kubectl apply -f -
helm template -n kargo kargo "${KARGO_DIR}" \
  --values "${KARGO_DIR}/config/envs/management/service.yaml" \
  --values "$values_file" \
  | kubectl apply -f -

# Apply Kargo project manifests (Project, Tasks, Warehouse, Stage, PAT secret)
kubectl create namespace homelab-management --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "${SCRIPT_DIR}/kargo/manifests/"

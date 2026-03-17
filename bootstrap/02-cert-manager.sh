#!/bin/sh

# Bootstrap cert-manager
#
# Kargo requires cert-manager for webhook TLS certificates.
# This must run before Kargo is installed.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CERTMANAGER_DIR="${SCRIPT_DIR}/charts/cert-manager"
helm dependency update "${CERTMANAGER_DIR}"

kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
helm template -n cert-manager cert-manager "${CERTMANAGER_DIR}" --include-crds \
  | kubectl apply -f -

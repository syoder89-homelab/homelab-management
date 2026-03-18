# homelab-management

Kubernetes management plane configuration for Scorpius (bare-metal homelab cluster). Deploys and manages **ArgoCD** and **Kargo** — the GitOps and progressive delivery tools that drive all other repositories.

## Architecture

This repository manages applications that run **only on the management cluster** (Scorpius). It is one of three GitOps repositories:

| Repository | Purpose | Deployed to |
|-----------|---------|-------------|
| **homelab-management** (this repo) | ArgoCD, Kargo (management plane) | Scorpius only |
| **homelab-infra** | cert-manager, 1Password Connect, Calico (infrastructure) | All clusters |
| **homelab-apps** | Frigate, Grafana, InfluxDB, etc. (workloads) | Per-app targeting |

## Applications

| Application | Version | Purpose |
|------------|---------|---------|
| ArgoCD | 9.4.3 | GitOps continuous deployment |
| Kargo | 1.9.3 | Progressive delivery / promotion pipeline |
| Kargo Config | — | Kargo project secrets and promotion policies |

## Bootstrap

The management cluster must be bootstrapped once before GitOps takes over. The bootstrap process runs in dependency order:

```
1Password Connect → cert-manager → ArgoCD → Root Applications → Kargo
```

### Prerequisites

- `kubectl` configured for the target cluster
- `op` CLI authenticated (1Password)
- `helm` v3.10+
- `htpasswd` (from `apache2-utils`)

### Run Bootstrap

```bash
cd bootstrap/
./bootstrap.sh
```

After bootstrap completes, ArgoCD and Kargo self-manage from this repository. The `management-root` Application syncs all management apps via GitOps.

### What Bootstrap Does

1. **01-onepassword-connect.sh** — Deploys 1Password Connect operator with secrets from `op` CLI (chicken-and-egg: can't be GitOpsed)
2. **02-cert-manager.sh** — Deploys cert-manager (required by Kargo for webhook TLS)
3. **03-argocd.sh** — Deploys a minimal ArgoCD installation
4. **04-apply-root-apps.sh** — Applies root ArgoCD Applications and AppProjects for all three repos
5. **05-kargo.sh** — Deploys Kargo with generated admin password, applies Kargo Project + Stages + Tasks

## Configuration Hierarchy

Configuration merges in this order (later wins):

1. `config/global/` — repo-wide defaults
2. `config/env-types/{type}/` — environment-type settings
3. `config/envs/{env}/` — environment-specific settings
4. `applications/{app}/config/global/` — app defaults
5. `applications/{app}/config/env-types/{type}/` — app env-type overrides
6. `applications/{app}/config/envs/{env}/` — app environment overrides

## GitOps Workflow

```
Commit to main
    ↓
Kargo Warehouse detects change
    ↓
Kargo Stage auto-promotes (creates PR)
    ↓
PR merged → env/management/{app} branch updated
    ↓
ArgoCD syncs to cluster
```

## Directory Structure

```
applications/              # Umbrella Helm charts
  argocd/                  # ArgoCD GitOps CD
  kargo/                   # Kargo progressive delivery
  kargo-config/            # Kargo project config + secrets

bootstrap/                 # One-time cluster setup
  01-onepassword-connect.sh  # Deploys 1Password Connect operator
  02-cert-manager.sh         # Deploys cert-manager
  03-argocd.sh               # Deploys minimal ArgoCD
  04-apply-root-apps.sh      # Applies root ArgoCD Applications + AppProjects
  05-kargo.sh                # Deploys Kargo with admin password
  bootstrap.sh               # Runs all scripts in order
  argocd/manifests/          # ArgoCD Applications, AppProjects, GitHub PAT
  charts/                    # Bootstrap-only Helm charts (cert-manager, 1password)
  kargo/manifests/           # Kargo Project + Tasks + Warehouse + Stages

charts/                    # Generator charts
  application-generator/   # Generates ArgoCD/Kargo resources
  config-generator/        # Renders hierarchical templated configs

config/                    # Repository-level configuration
  global/                  # Applied to all apps
  env-types/               # Per environment-type settings
  envs/                    # Per environment settings
```

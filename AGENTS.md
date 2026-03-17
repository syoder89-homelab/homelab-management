# AI Agent Guide

This file provides context for AI coding agents working in this repository.

## Repository Overview

This is a **Kubernetes management plane** repository for a home lab. It deploys and manages **ArgoCD** (GitOps) and **Kargo** (progressive delivery) on the management cluster (Scorpius). These tools then manage all other repositories. The repository does NOT contain application source code — it contains only deployment configuration for management plane components.

## Technology Stack

- **Kubernetes** (v1.24+): Container orchestration
- **Helm** (v3.10+): Chart-based Kubernetes package management
- **ArgoCD**: GitOps continuous deployment (syncs Git → cluster)
- **Kargo**: Progressive delivery (staged promotions between environments)
- **1Password Connect**: Secure secrets integration with 1Password vaults
- **YAML**: All configuration is YAML-based

## Key Architecture Concepts

### Three-Repo Model

| Repository | Purpose | Deployed to |
|-----------|---------|-------------|
| **homelab-management** (this repo) | ArgoCD, Kargo | Scorpius only |
| **homelab-infra** | cert-manager, 1Password Connect, Calico | All clusters |
| **homelab-apps** | Frigate, Grafana, InfluxDB, etc. | Per-app targeting |

### Umbrella Charts

Each application in `applications/` is an **umbrella Helm chart** — a thin wrapper around an upstream chart (declared as a dependency in `Chart.yaml`). The umbrella chart adds:
- Environment-specific configuration (`config/`)
- Kubernetes secrets and custom resources (`templates/`)
- Override values (`values.yaml`)

### Two Generator Charts

1. **`application-generator`**: Auto-discovers applications from `applications/*/Chart.yaml` and generates ArgoCD Applications, Kargo Stages, and Warehouses.

2. **`config-generator`**: Aggregates and renders templated YAML configs from a hierarchical directory structure.

Both generators use a recursive `better-tpl` helper that processes Helm templates within templates.

### Single Environment

This repo has one environment: `management` (deployed to Scorpius, the bare-metal management cluster). Unlike homelab-infra and homelab-apps, there is no multi-environment promotion chain.

### Configuration Hierarchy

Configuration merges in this order (later wins):
1. `config/global/` — repo-wide defaults
2. `config/env-types/{type}/` — environment-type settings
3. `config/envs/{env}/` — environment-specific settings
4. `applications/{app}/config/global/` — app defaults
5. `applications/{app}/config/env-types/{type}/` — app env-type overrides
6. `applications/{app}/config/envs/{env}/` — app environment overrides

### Template Variables

In config YAML files, these Helm template variables are available:
- `.Values.envName` — environment name (`management`)
- `.Values.envType` — environment type (`management`)
- `.Values.appName` — application name (e.g., `argocd`, `kargo`)

### Custom Chart.yaml Fields

Application `Chart.yaml` files use custom fields consumed by the application-generator:
- `namespace`: Target Kubernetes namespace (defaults to app name)
- `releaseName`: Helm release name (defaults to app name)
- `argocd.ignoreDifferences`: Passed through to the generated ArgoCD Application

## Directory Structure

```
applications/              # Umbrella Helm charts (one per management component)
  argocd/                  # ArgoCD - GitOps CD
  kargo/                   # Kargo - progressive delivery
  kargo-config/            # Kargo project configuration + secrets

bootstrap/                 # One-time management cluster setup
  manifests/               # ArgoCD Applications + AppProjects for all repos
  kargo/                   # Kargo Project + Tasks + Warehouse + Stages

charts/                    # Reusable Helm chart generators
  application-generator/   # Generates ArgoCD/Kargo resources
  config-generator/        # Renders hierarchical templated configs

config/                    # Repository-level configuration
  global/                  # Applied to all apps
  env-types/               # Per environment-type settings
  envs/                    # Per environment settings
```

## Conventions & Patterns

### Naming
- Application directories use kebab-case: `kargo-config`
- Generated ArgoCD resource names follow `{env}-{app}` pattern (e.g., `management-argocd`)
- Kargo project name: `homelab-management`

### File Patterns
- Secrets go in `templates/*-credentials.yaml` or `templates/*-secret.yaml`
- Config files use standard Helm template syntax (`{{ .Values.x }}`)
- All YAML files in `config/` directories may contain Helm templates

### Chart Structure
- Every application MUST have a `Chart.yaml` (this is how auto-discovery works)
- `values.yaml` contains default overrides for the upstream chart
- Dependencies are declared in `Chart.yaml` under `dependencies:`

### Git Workflow
- `main` branch is the source of truth
- Kargo promotes changes via branches prefixed with `env/management/{appName}`
- Promotions create PRs for review (`asPR: true`)
- **All commits MUST be GPG-signed.** Never use `--no-gpg-sign`, `-c commit.gpgsign=false`, or any other mechanism to bypass commit signing.

## Common Tasks

### Adding a New Management Component
1. Create `applications/{app-name}/Chart.yaml` with upstream dependency
2. Create `applications/{app-name}/values.yaml` with default overrides
3. Add environment configs in `applications/{app-name}/config/envs/management/`
4. Add templates/secrets in `applications/{app-name}/templates/` if needed
5. The application-generator will auto-discover it from `Chart.yaml`

### Updating a Component Version
1. Edit `dependencies[].version` in `applications/{app}/Chart.yaml`
2. Update `appVersion` in `Chart.yaml` to match
3. Commit and let Kargo promote

### Validating Changes
```bash
helm lint applications/{app-name}
helm template applications/{app-name}
```

## Important Warnings

- **All commits MUST be GPG-signed.** Never bypass or disable commit signing.
- **Never commit secrets in plaintext** — use External Secrets Operator with 1Password Connect.
- **Do not manually create ArgoCD Application or Kargo Stage manifests** — the `application-generator` chart auto-generates them.
- **Do not manually edit generated manifests** — they are produced by the generator pipeline.

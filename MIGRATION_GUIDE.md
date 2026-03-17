# Migration Guide: 3-Repo Separation

This document covers the safe migration from the old single-repo model (everything in `homelab-infra`) to the new 3-repo architecture (`homelab-management`, `homelab-infra`, `homelab-apps`).

## What Changed

The management plane (ArgoCD, Kargo, kargo-config) was moved out of `homelab-infra` into this repo (`homelab-management`). The `homelab-infra` repo now only contains cross-cluster infrastructure (cert-manager, onepassword-connect, calico).

## Current Deployed State

The `env/prod/application-generator` branch in `homelab-infra` currently has **6 Applications**, **6 Stages**, and **6 Warehouses**:

| Resource | Still in homelab-infra? | New Location |
|----------|------------------------|--------------|
| `prod-argocd` | **NO** — removed | homelab-management |
| `prod-kargo` | **NO** — removed | homelab-management |
| `prod-kargo-config-infra` | **NO** — removed | homelab-management |
| `prod-calico` | Yes | — |
| `prod-cert-manager` | Yes | — |
| `prod-onepassword-connect` | Yes | — |

After the next Kargo promotion of `homelab-infra`, only 3 resources will remain on that branch.

## Risks

### 1. Application Pruning (HIGH priority)

The `prod-infra` root Application has `prune: true` and `selfHeal: true`. When the new `env/prod/application-generator` branch is promoted with only 3 apps, ArgoCD will **prune** the 3 removed Application objects (`prod-argocd`, `prod-kargo`, `prod-kargo-config-infra`) along with their Kargo Stages and Warehouses.

### 2. Cascade Deletion — NOT a risk

The generated Application objects do **not** have `resources-finalizer.argocd.argoproj.io`. This means pruning deletes the Application CR only — it does **NOT** cascade-delete the Kubernetes resources those Applications managed (ArgoCD pods, Kargo pods, etc.). Those resources become orphaned but keep running.

> **Warning:** If someone has manually added the `resources-finalizer` to any of these Applications in the cluster, cascade deletion **would** occur. Verify before proceeding:
> ```bash
> kubectl get application prod-argocd prod-kargo prod-kargo-config-infra -n argocd -o jsonpath='{range .items[*]}{.metadata.name}: {.metadata.finalizers}{"\n"}{end}'
> ```

### 3. Unmanaged Window

Between infra pruning the old Applications and management creating the new ones, ArgoCD and Kargo will be running but unmanaged by any ArgoCD Application. This is a low-risk state (services keep running) but should be minimized.

### 4. Stale Remote Branches (LOW priority)

These orphaned branches will remain in `homelab-infra` after migration:

- `env/prod/argocd`
- `env/prod/kargo`
- `env/prod/kargo-config-infra`
- `env/prod/kargo-apps-deprecated`
- `env/prod/mosquitto`
- `env/prod/mosquitto-taylor`

They are harmless (no Application references them) but should be cleaned up.

## Safe Migration Sequence

### Step 1: Verify no finalizers on existing Applications

```bash
kubectl get application prod-argocd prod-kargo prod-kargo-config-infra -n argocd \
  -o jsonpath='{range .items[*]}{.metadata.name}: {.metadata.finalizers}{"\n"}{end}'
```

All three should show empty finalizers (`[]` or no output). If any has `resources-finalizer.argocd.argoproj.io`, remove it first:

```bash
kubectl patch application <name> -n argocd --type=json \
  -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
```

### Step 2: Deploy homelab-management

Push this repo to GitHub and run the bootstrap:

```bash
cd bootstrap
./bootstrap.sh
```

This will:
1. Deploy 1Password Connect
2. Deploy cert-manager
3. Install ArgoCD (already running — this ensures it's configured correctly)
4. Apply AppProjects and root Applications (`management-root`, `prod-infra`, `prod-apps`)
5. Install Kargo and apply Kargo project resources

After this step, the `management-root` Application will be managing ArgoCD and Kargo via the management repo's application-generator.

### Step 3: Pre-delete old infra Applications

Before pushing `homelab-infra` changes, delete the 3 Applications that are moving to management so the prune is a no-op:

```bash
kubectl delete application prod-argocd prod-kargo prod-kargo-config-infra -n argocd --wait=false
```

Also delete the old Kargo resources:

```bash
kubectl delete stage prod-argocd prod-kargo prod-kargo-config-infra -n homelab-infra --ignore-not-found
kubectl delete warehouse argocd kargo kargo-config-infra -n homelab-infra --ignore-not-found
```

### Step 4: Push homelab-infra changes

Push the updated `main` branch to GitHub. Kargo will detect the changes and promote to `env/prod/application-generator`. The `prod-infra` root Application will sync and see only 3 apps — no pruning needed since the old ones were already deleted.

### Step 5: Clean up stale remote branches

```bash
cd /path/to/homelab-infra
git push origin --delete \
  env/prod/argocd \
  env/prod/kargo \
  env/prod/kargo-config-infra \
  env/prod/kargo-apps-deprecated \
  env/prod/mosquitto \
  env/prod/mosquitto-taylor
```

### Step 6: Verify

```bash
# Check management Applications are healthy
kubectl get applications -n argocd -l argocd.argoproj.io/managed-by=management-root

# Check infra Applications are healthy
kubectl get applications -n argocd -l argocd.argoproj.io/managed-by=prod-infra

# Check Kargo projects exist
kubectl get projects -A

# Check all pods are running
kubectl get pods -n argocd
kubectl get pods -n kargo
kubectl get pods -n cert-manager
kubectl get pods -n onepassword-connect
```

## Alternative: Conservative Approach

If you want to avoid any risk of accidental pruning, you can temporarily disable pruning on `prod-infra` before pushing changes:

```bash
# Disable auto-prune
kubectl patch application prod-infra -n argocd --type=merge \
  -p='{"spec":{"syncPolicy":{"automated":{"prune":false}}}}'

# Push homelab-infra changes and let Kargo promote
# ...

# Manually delete old Applications
kubectl delete application prod-argocd prod-kargo prod-kargo-config-infra -n argocd

# Re-enable auto-prune
kubectl patch application prod-infra -n argocd --type=merge \
  -p='{"spec":{"syncPolicy":{"automated":{"prune":true}}}}'
```

## Rollback

If something goes wrong, the old `env/prod/application-generator` branch still exists with all 6 apps. You can force-reset to the previous commit:

```bash
# Find the previous good commit
git log origin/env/prod/application-generator --oneline -5

# Reset the branch
git push origin <previous-commit>:refs/heads/env/prod/application-generator --force
```

ArgoCD will automatically sync back to the old state with all 6 Applications.

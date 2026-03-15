# Robo Stack — Deployment Guide

## Pipeline Overview

The Robo Stack project uses a three-stage GitOps deployment pipeline. Each
environment has its own workflow, cluster, and promotion gate.

```
                         Robo Stack Deployment Pipeline

  ┌──────────┐     push to main     ┌──────────┐
  │  Commit  │ ───────────────────>  │   DEV    │  (automatic)
  └──────────┘                       └──────────┘
                                          │
                                     tag v*.*.*
                                          │
                                          v
                                     ┌──────────┐
                                     │ STAGING  │  (automatic on tag)
                                     └──────────┘
                                          │
                                    manual dispatch
                                    + "DEPLOY" gate
                                    + env approval
                                          │
                                          v
                                     ┌──────────┐
                                     │   PROD   │  (manual + approval)
                                     └──────────┘
```

| Environment | Trigger | Workflow | Namespace | Image Tag |
|-------------|---------|----------|-----------|-----------|
| Dev | Push to `main` | `deploy-dev.yml` | `robo-stack` | `main-<sha>` |
| Staging | Tag `v*.*.*` | `deploy-staging.yml` | `robo-stack-staging` | `v*.*.*` |
| Production | Manual dispatch | `deploy-prod.yml` | `robo-stack-prod` | `v*.*.*` (from staging) |

---

## How to Deploy

### Dev (Automatic)

Every push to `main` triggers a dev deployment automatically:

1. Merge your PR to `main`.
2. The `Deploy to Dev` workflow starts immediately.
3. It builds a container image, pushes it to GHCR, and deploys to the dev cluster.
4. A smoke test verifies the health endpoint.
5. Monitor the workflow run at: **Actions > Deploy to Dev**

No manual steps are required. If the deployment fails, an automatic rollback
is executed.

### Staging (Tag-Triggered)

Staging deployments are triggered by pushing a semver tag:

1. Ensure your changes are on `main` and dev deployment is healthy.
2. Create and push a semver tag:
   ```bash
   git tag v1.2.0
   git push origin v1.2.0
   ```
3. The `Deploy to Staging` workflow starts automatically.
4. It builds the image tagged with the version, deploys to staging, and runs
   integration tests (health, metrics, replica checks).
5. Monitor the workflow run at: **Actions > Deploy to Staging**

If the deployment fails, an automatic rollback is executed and a GitHub Issue
is created with failure details.

### Production (Manual with Approval)

Production deployments require manual dispatch and environment approval:

1. Confirm the desired version is successfully deployed to staging.
2. Go to **Actions > Deploy to Production > Run workflow**.
3. Fill in the fields:
   - **Image tag**: The semver tag from staging (e.g., `v1.2.0`)
   - **Confirm**: Type `DEPLOY` (exact match required)
4. Click **Run workflow**.
5. A reviewer with production environment access must approve the deployment.
6. The workflow verifies the staging image exists (no rebuild), deploys to
   production, runs smoke tests, and executes a 5-minute soak period with
   Prometheus alert monitoring.

If the deployment fails at any step, an automatic rollback is executed and a
**Critical** GitHub Issue is created.

---

## How to Rollback

### Automated Rollback

All three deployment workflows include automatic rollback on failure. If a
deployment or any post-deploy check fails:

1. `kubectl rollout undo` reverts to the previous revision.
2. The deployment status is marked as `failure` in GitHub.
3. For staging and production, a GitHub Issue is created with details.

No manual intervention is needed for automated rollbacks.

### Manual Rollback

Use the `scripts/rollback.sh` script for manual rollbacks:

```bash
# Rollback to the previous revision
./scripts/rollback.sh robo-stack claude-proxy

# Rollback to a specific revision
./scripts/rollback.sh robo-stack-staging claude-proxy 3

# Rollback production
./scripts/rollback.sh robo-stack-prod claude-proxy
```

The script:
- Validates the namespace and deployment exist
- Displays current deployment state and rollout history
- Executes the rollback
- Waits for the rollout to complete (180-second timeout)
- Reports previous and current image versions

You can also rollback directly with kubectl:

```bash
# View rollout history
kubectl rollout history deployment/claude-proxy -n robo-stack

# Undo to previous
kubectl rollout undo deployment/claude-proxy -n robo-stack

# Undo to specific revision
kubectl rollout undo deployment/claude-proxy -n robo-stack --to-revision=2

# Verify
kubectl rollout status deployment/claude-proxy -n robo-stack
```

---

## GitHub Secrets Required

The following repository secrets must be configured under **Settings > Secrets
and variables > Actions**:

| Secret | Description | Used By |
|--------|-------------|---------|
| `KUBECONFIG_DEV` | Base64-encoded kubeconfig for the dev K8s cluster | `deploy-dev.yml` |
| `KUBECONFIG_STAGING` | Base64-encoded kubeconfig for the staging K8s cluster | `deploy-staging.yml` |
| `KUBECONFIG_PROD` | Base64-encoded kubeconfig for the production K8s cluster | `deploy-prod.yml` |

`GITHUB_TOKEN` is provided automatically by GitHub Actions and is used for GHCR
authentication and creating deployments/issues. No additional token setup is
needed for GHCR access.

### Encoding a kubeconfig as a secret

```bash
# Encode the kubeconfig file
base64 -w 0 < ~/.kube/config-dev > kubeconfig-dev.b64

# Add it as a GitHub secret (via CLI)
gh secret set KUBECONFIG_DEV < kubeconfig-dev.b64

# Clean up the encoded file
rm kubeconfig-dev.b64
```

### GitHub Environments

Three environments must be configured under **Settings > Environments**:

- **dev** — No protection rules required.
- **staging** — Optional: require status checks.
- **production** — Required: add at least one reviewer for deployment approval.

---

## Troubleshooting Failed Deployments

### Deployment stuck in "Pending"

```bash
# Check pod status
kubectl get pods -l app=claude-proxy -n <namespace>

# Describe the pod for events
kubectl describe pod <pod-name> -n <namespace>

# Common causes: ImagePullBackOff, insufficient resources, pending PVCs
```

### Health check failing after deploy

```bash
# Check the service endpoint
kubectl get svc claude-proxy -n <namespace>

# Port-forward to test locally
kubectl port-forward svc/claude-proxy 8080:80 -n <namespace>
curl http://localhost:8080/health

# Check container logs
kubectl logs -l app=claude-proxy -n <namespace> --tail=100
```

### Rollout timeout

```bash
# Check rollout status
kubectl rollout status deployment/claude-proxy -n <namespace>

# Check for stuck ReplicaSets
kubectl get rs -l app=claude-proxy -n <namespace>

# Force a manual rollback if needed
kubectl rollout undo deployment/claude-proxy -n <namespace>
```

### Image not found (GHCR)

```bash
# Verify the image exists in GHCR
docker manifest inspect ghcr.io/littleyeti-dev/robo-stack/claude-proxy:<tag>

# Check GHCR package visibility
# Go to: https://github.com/orgs/LittleYeti-Dev/packages

# Verify the image pull secret exists in the namespace
kubectl get secret ghcr-pull-secret -n <namespace>
```

### Production deployment blocked by approval

1. Go to the workflow run in GitHub Actions.
2. Click **Review deployments**.
3. Select the `production` environment.
4. Click **Approve and deploy**.

Only users with write access to the `production` environment can approve.

### Viewing deployment metadata

Each deployment creates a `deployment-metadata` ConfigMap with details:

```bash
kubectl get configmap deployment-metadata -n <namespace> -o yaml
```

This shows: deployed-at, image-tag, git-sha, deployed-by, and environment.

### Checking deployment history in GitHub

Go to **Settings > Environments > \<env\>** to see the deployment history,
or use the GitHub API:

```bash
gh api repos/LittleYeti-Dev/robo-stack/deployments \
  --jq '.[] | {id, environment, ref: .ref, created_at}'
```

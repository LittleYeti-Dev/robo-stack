# Sprint 3 — Deployment Workflow Design

**Story:** S3.1 — Process Design
**Epic:** E3 — Hybrid Cloud Deployment
**Author:** Claude (Cowork)
**Approved by:** Yeti (pending)

---

## 1. Environment Topology

| Environment | Cluster | Namespace | Purpose | Promotion |
|-------------|---------|-----------|---------|-----------|
| **dev** | K3s (EC2) | `robo-stack` | Active development, integration testing | Automatic on merge to `main` |
| **staging** | K3s (EC2) | `robo-stack-staging` | Pre-production validation, smoke tests | Tag/release trigger |
| **prod** | K3s (EC2) | `robo-stack-prod` | Production workloads | Manual approval gate |

> **Note:** All three environments run on the same K3s cluster (single t3.xlarge node). Resource quotas per namespace prevent noisy-neighbor issues. Multi-cluster promotion is a future E5 goal.

## 2. Deployment Flow

```
Developer pushes → Feature branch CI (lint, test, build)
                         │
                    Open PR → AI code review + CodeQL
                         │
                    Merge to main → Auto-deploy to dev namespace
                         │
                    Create release tag (vX.Y.Z) → Deploy to staging
                         │
                    Manual approval (GitHub Environment) → Deploy to prod
```

### 2.1 Dev Deployment (Automatic)

**Trigger:** Push/merge to `main` branch
**Workflow:** `.github/workflows/deploy-dev.yml`

1. Build container images (reuse docker-build.yml matrix)
2. Tag images with `main-<sha>` and `latest`
3. Apply Kustomize overlay: `k8s/overlays/dev/`
4. `kubectl apply` to `robo-stack` namespace
5. Wait for rollout: `kubectl rollout status`
6. Run smoke test: health check endpoints
7. Post deployment status to GitHub (environment badge)

### 2.2 Staging Deployment (Tag-Triggered)

**Trigger:** Git tag matching `v*.*.*`
**Workflow:** `.github/workflows/deploy-staging.yml`

1. Build images tagged with semver (`v1.2.3`)
2. Apply Kustomize overlay: `k8s/overlays/staging/`
3. Deploy to `robo-stack-staging` namespace
4. Run integration test suite
5. Create GitHub Deployment record

### 2.3 Production Deployment (Manual Gate)

**Trigger:** Manual workflow dispatch + GitHub Environment approval
**Workflow:** `.github/workflows/deploy-prod.yml`

1. Require GitHub Environment reviewers (Yeti)
2. Pull staging-validated image (same tag)
3. Apply Kustomize overlay: `k8s/overlays/prod/`
4. Deploy to `robo-stack-prod` namespace
5. Run production smoke tests
6. Monitor for 5 minutes (Prometheus alerts)
7. Mark deployment as successful or trigger rollback

## 3. Rollback Strategy

### Automatic Rollback
- Kubernetes rolling update with `maxUnavailable: 0` and `maxSurge: 1`
- Readiness probes gate traffic; failed pods never receive requests
- `kubectl rollout undo` if deployment doesn't reach Ready within 5 minutes

### Manual Rollback
```bash
# Roll back to previous revision
kubectl rollout undo deployment/<name> -n <namespace>

# Roll back to specific revision
kubectl rollout undo deployment/<name> -n <namespace> --to-revision=<N>

# Verify rollback
kubectl rollout status deployment/<name> -n <namespace>
```

### Image Pinning
Every deployment records the exact image SHA in a ConfigMap:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: deployment-metadata
data:
  deployed-at: "2026-03-13T12:00:00Z"
  image-tag: "v1.2.3"
  git-sha: "abc1234"
  deployed-by: "github-actions"
```

## 4. Configuration Management

### Kustomize Structure
```
k8s/
├── base/                    # Shared manifests
│   ├── claude-proxy/
│   ├── dev-tools/
│   └── kustomization.yaml
├── overlays/
│   ├── dev/                 # Dev overrides
│   │   ├── kustomization.yaml
│   │   ├── resource-limits.yaml
│   │   └── replicas.yaml
│   ├── staging/             # Staging overrides
│   │   ├── kustomization.yaml
│   │   ├── resource-limits.yaml
│   │   └── replicas.yaml
│   └── prod/                # Prod overrides
│       ├── kustomization.yaml
│       ├── resource-limits.yaml
│       ├── replicas.yaml
│       └── network-policy.yaml
└── monitoring/              # Prometheus + Grafana
```

### Environment Differences

| Setting | Dev | Staging | Prod |
|---------|-----|---------|------|
| Replicas (claude-proxy) | 1 | 1 | 2 |
| CPU limit | 500m | 500m | 1000m |
| Memory limit | 512Mi | 512Mi | 1Gi |
| Log level | DEBUG | INFO | WARN |
| Rate limit (RPM) | 10 | 20 | 50 |
| Network policies | None | Basic | Strict |
| Resource quotas | Soft | Hard | Hard |

## 5. Secret Management

| Environment | Strategy |
|-------------|----------|
| Dev | K8s Secrets (base64), rotated manually |
| Staging | K8s Secrets, sourced from GitHub Secrets via deploy workflow |
| Prod | K8s Secrets with RBAC, future: external secrets operator |

**Secret rotation process:**
1. Update secret in GitHub Secrets (or source of truth)
2. Re-run deploy workflow for target environment
3. Pods restart with new secret via `kubectl rollout restart`

## 6. CI/CD Pipeline Summary

```
┌─────────────┐    ┌──────────┐    ┌───────────┐    ┌──────────┐
│ Feature      │    │  Main    │    │  Tagged   │    │  Prod    │
│ Branch       │───►│  Branch  │───►│  Release  │───►│  Deploy  │
│              │    │          │    │           │    │          │
│ • lint       │    │ • build  │    │ • staging │    │ • manual │
│ • test       │    │ • push   │    │ • smoke   │    │ • gate   │
│ • CodeQL     │    │ • deploy │    │ • integ   │    │ • deploy │
│ • AI review  │    │   dev    │    │   test    │    │ • verify │
└─────────────┘    └──────────┘    └───────────┘    └──────────┘
```

## 7. Monitoring Integration Points

Each deployment workflow includes monitoring hooks:
- **Pre-deploy:** Snapshot current Prometheus metrics
- **Post-deploy:** Compare error rates for 5 minutes
- **Alert:** If error rate increases >10%, flag deployment
- **Grafana annotation:** Mark deployment timestamp on dashboards

See: [Monitoring & Observability Requirements](./s3-monitoring-requirements.md)

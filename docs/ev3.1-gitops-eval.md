# EV3.1: Deployment Strategy — ArgoCD vs GitHub Actions GitOps

**Story:** EV3.1 — Eval Gate
**Epic:** E3 — Hybrid Cloud Deployment
**Author:** Claude (Cowork)
**Decision:** GitHub Actions GitOps (Recommended)
**Status:** Pending Yeti sign-off

---

## Context

Robo Stack needs an automated deployment pipeline that promotes changes through dev → staging → prod environments. Two approaches are evaluated: ArgoCD (dedicated GitOps controller running on the cluster) and GitHub Actions-based GitOps (CI/CD-driven kubectl apply).

### Constraints

- **Single node:** t3.xlarge (4 vCPU, 16 GB RAM) running K3s
- **Team size:** 1 developer (Yeti) + Claude AI agents
- **Current CI:** GitHub Actions (9 workflows, all green)
- **Workloads:** 4 pods in robo-stack namespace + monitoring stack (S3.2)

---

## Evaluation Criteria

| Criteria | Weight | ArgoCD | GH Actions GitOps | Notes |
|----------|--------|--------|--------------------|-------|
| Resource overhead | 25% | 2/5 | 5/5 | ArgoCD needs ~700Mi RAM + 500m CPU |
| Setup complexity | 20% | 2/5 | 4/5 | ArgoCD: CRDs, RBAC, config; GHA: workflow YAML |
| Operational complexity | 15% | 3/5 | 4/5 | ArgoCD has its own upgrade cycle, CRD management |
| Features (drift detection) | 15% | 5/5 | 2/5 | ArgoCD's core strength; GHA needs manual checks |
| Features (rollback) | 10% | 5/5 | 3/5 | ArgoCD: one-click; GHA: workflow dispatch |
| Team fit (solo dev) | 10% | 2/5 | 5/5 | ArgoCD designed for multi-team; overkill for 1 dev |
| Future scalability | 5% | 5/5 | 3/5 | ArgoCD scales to multi-cluster naturally |
| **Weighted Score** | **100%** | **2.95** | **4.00** | |

---

## Detailed Analysis

### Option A: ArgoCD on K3s

**Architecture:**
- ArgoCD server (UI/API) + repo-server + Redis + application-controller
- Watches Git repo, syncs cluster state to match desired state
- Declarative Application CRDs define what to deploy

**Resource Requirements:**

| Component | CPU Request | Memory Request | Memory Limit |
|-----------|-------------|----------------|--------------|
| argocd-server | 100m | 128Mi | 256Mi |
| argocd-repo-server | 100m | 128Mi | 256Mi |
| argocd-application-controller | 100m | 128Mi | 512Mi |
| argocd-redis | 50m | 64Mi | 128Mi |
| **Total** | **350m** | **448Mi** | **1152Mi** |

> This is **on top of** the ~450m/1088Mi monitoring stack (S3.2) and existing workloads. On a t3.xlarge with 16 GB RAM, it fits technically but leaves little headroom. Combined monitoring + ArgoCD would consume ~800m CPU and ~1.5 GB RAM just for infrastructure.

**Pros:**
- True GitOps: continuous reconciliation, drift detection
- Built-in UI for deployment visualization
- Rollback with one click
- Multi-cluster support for future growth
- RBAC for team-based access control

**Cons:**
- ~1.1 GB RAM overhead on already-constrained node
- CRD management adds operational burden
- ArgoCD itself needs upgrading and monitoring
- Designed for multi-team orgs; overkill for solo developer
- Adds another layer of abstraction to debug when things break
- Kubeconfig management between ArgoCD and cluster is another secret to manage

### Option B: GitHub Actions GitOps

**Architecture:**
- GitHub Actions workflows triggered by merge/tag/manual dispatch
- Workflows run on GitHub-hosted runners (zero cluster resources)
- kubectl apply with Kustomize overlays
- GitHub Environments for approval gates

**Resource Requirements:**

| Component | CPU | Memory | Notes |
|-----------|-----|--------|-------|
| On-cluster | 0 | 0 | Runs on GH-hosted runners |
| Kubeconfig secret | — | — | Stored in GitHub Secrets |

> Zero additional resource consumption on the K3s node.

**Pros:**
- Zero cluster resource overhead
- Builds on existing CI infrastructure (9 workflows already)
- GitHub Environments provide approval gates natively
- Deployment status visible in repo (badges, deployment history)
- Simpler debugging: everything is in workflow logs
- No new CRDs, no additional upgrade cycle
- Team already proficient with GH Actions

**Cons:**
- No continuous drift detection (only deploys on trigger)
- Rollback requires workflow dispatch or `kubectl rollout undo`
- No built-in deployment visualization (would need Grafana dashboard)
- Less elegant for multi-cluster scenarios (future concern)
- Kubeconfig as a GitHub Secret is a security surface

---

## Drift Detection Gap Analysis

The main feature gap is drift detection. Mitigation strategies for GH Actions:

1. **Scheduled validation workflow:** Run `kubectl diff` against Kustomize output every hour; alert on drift
2. **Grafana dashboard:** Show expected vs actual pod versions
3. **Post-deploy verification:** Each deploy workflow checks rollout status
4. **Manual audit:** `kustomize build | kubectl diff -f -` as a periodic check

These mitigations bring GH Actions to ~80% of ArgoCD's drift detection capability at zero resource cost.

---

## Recommendation

**GitHub Actions GitOps** is the recommended approach for Sprint 3.

**Rationale:**
1. **Resource efficiency:** Zero overhead vs ~1.1 GB RAM for ArgoCD. On a single t3.xlarge running monitoring + dev workloads, this matters.
2. **Simplicity:** One less system to operate, upgrade, and debug. Sprint 2 taught us that simpler approaches (GHCR over ECR, NodePort over Ingress, ConfigMap over custom images) reduce incidents.
3. **Team fit:** Solo developer + AI agents. ArgoCD's multi-team RBAC features provide no value.
4. **Existing investment:** 9 GH Actions workflows already running and maintained. Adding deploy workflows is incremental, not architectural.
5. **Reversibility:** If Robo Stack grows to multi-cluster or multi-team in E5/E6, ArgoCD can be adopted then with the Kustomize structure already in place.

**Migration path to ArgoCD (future):**
- Kustomize overlays (S3.3) are ArgoCD-compatible
- GitHub Actions deploy workflows can coexist with ArgoCD during migration
- ArgoCD adoption is a ~1 sprint effort when needed

---

## Decision

| | |
|---|---|
| **Chosen option** | GitHub Actions GitOps |
| **Score** | 4.00 / 5.00 |
| **Key factor** | Zero resource overhead on constrained single-node cluster |
| **Approved by** | Pending Yeti sign-off |
| **Revisit trigger** | Multi-cluster deployment or team size > 3 |

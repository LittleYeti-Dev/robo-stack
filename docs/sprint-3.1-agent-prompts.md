# Sprint 3.1 — Agent Task Prompts
## Robo Stack | Epic 3: Hybrid Cloud Deployment (continued) + Ops Debt

**Version:** 1.0
**Date:** 2026-03-15
**Sprint:** Sprint 3.1 — Hybrid Cloud Deployment + Architecture + Threat Model
**Prepared by:** Taskmaster
**For:** Claude Code (all agentic tasks)
**Repo:** https://github.com/LittleYeti-Dev/robo-stack
**Board:** https://github.com/users/LittleYeti-Dev/projects/1
**Milestone:** Sprint 3.1 (Due: 2026-03-27)

> **Handoff document.** A fresh agent session reads this file and executes. No project history needed.

---

## Agent Routing — Sprint 3.1

All agentic tasks route to Claude (per Sprint 1 finding: Copilot Agent Mode scored 1/5).

| Story | Task | Agent | Persona | Wave |
|-------|------|-------|---------|------|
| S3.2 | Monitoring & Observability Stack | Claude Code | DevOps | 1 |
| S3.6 | Architecture Document (HTML) | Claude Code | Platform Architect | 1 |
| OPS-B2/B3/B5/B6/B8 | Ops Debt Items | Claude Code | Taskmaster | 1 |
| S3.3 | Multi-Environment Config | Claude Code | DevOps | 2 |
| S3.7 | MITRE ATT&CK Threat Model (HTML) | Claude Code | Overwatch | 2 (blocked by S3.6) |
| S3.4 | Deployment Pipeline / GitOps | Claude Code | DevOps | 3 (depends on S3.3) |
| S3.5 | Production Readiness & Hardening | Claude Code | DevOps | 3 (depends on S3.2, S3.3, S3.4) |
| TP3.1 | Sprint 3 Touchpoint | Claude Cowork | Taskmaster | Gate |
| RETRO-3.1 | Sprint 3.1 Retrospective | Claude Cowork | Taskmaster | Gate (last to close) |

## Execution Order (Waves)

```
WAVE 1 (parallel — no dependencies)
├── S3.2   Monitoring & Observability ──────────────────────┐
├── S3.6   Architecture Document (HTML) ────────────────────┤
└── OPS    B2, B3, B5, B6, B8 ─────────────────────────────┤
                                                             │
WAVE 2 (depends on Wave 1)                                   │
├── S3.3   Multi-Environment Config (needs S3.2 namespace)──┤
└── S3.7   Threat Model (blocked by S3.6) ──────────────────┤
                                                             │
WAVE 3 (depends on Wave 2)                                   │
├── S3.4   GitOps Pipeline (needs S3.3 overlays) ───────────┤
└── S3.5   Production Readiness (needs S3.2+S3.3+S3.4) ────┤
                                                             │
GATE                                                         │
├── TP3.1  Touchpoint (after all build stories) ────────────┤
└── RETRO-3.1  Retrospective (LAST to close) ───────────────┘
```

---

## SHARED CONTEXT — All Prompts

```
INFRASTRUCTURE STATE (as of 2026-03-15):
- AWS EC2: t3.xlarge (4 vCPU, 16GB RAM), us-east-1a
- Instance: i-0760725a72f766ba9
- Public IP: 54.196.112.58
- K8s: K3s v1.34.5 single-node cluster
- K8s API: https://54.196.112.58:6443
- Container Registry: GitHub Container Registry (GHCR)
- Namespaces: robo-stack (dev)
- Stack: Docker 29.3.0, Helm 3.20.1, Node.js 20, Python 3.10, Terraform 1.7
- CI/CD: 9 GitHub Actions workflows (all green)
- Cost: ~$155/month at full uptime

DECISIONS MADE:
- EV1.1: K3s over Minikube (lighter footprint)
- EV2.1: Cloud-first Claude API over local model serving
- EV3.1: GitHub Actions GitOps over ArgoCD (zero cluster overhead, scored 4.0/5)
- Agent routing: Claude for all agentic work; Copilot for inline completion only

REPO STRUCTURE:
robo-stack/
├── .github/workflows/     # 9 CI/CD workflows
├── docs/                  # Decision docs, retros, guides
├── k8s/
│   ├── base/              # Shared K8s manifests (not yet created)
│   ├── overlays/          # Per-env Kustomize overlays (not yet created)
│   ├── claude-proxy/      # Claude API proxy (deployed)
│   ├── dev-tools/         # Code Server, Jupyter, Node Dev
│   └── monitoring/        # Prometheus + Grafana + Loki (not yet created)
├── scripts/               # Automation scripts
└── terraform/             # AWS IaC (VPC, EC2, IAM, SGs)
```

---

## WAVE 1 PROMPTS

---

### PROMPT 1: S3.2 — Monitoring & Observability Stack
**Agent:** Claude Code
**GitHub Issue:** #30
**Persona:** DevOps Engineer
**Wave:** 1 (no dependencies)

```
You are the DevOps Engineer for the Robo Stack project — a hybrid AI development stack running on AWS EC2 with K3s Kubernetes.

TASK: Build and deploy the monitoring and observability stack.

CONTEXT:
- Repo: https://github.com/LittleYeti-Dev/robo-stack
- Branch: feature/robo-stack-e3-monitoring
- Monitoring requirements doc: docs/s3-monitoring-requirements.md
- Single K3s node: t3.xlarge (4 vCPU, 16GB RAM)
- Resource budget: 450m CPU, 1088Mi RAM for entire monitoring stack
- All monitoring is self-hosted on the K3s cluster (no external SaaS)

DELIVERABLES:

1. Create k8s/monitoring/ directory with all manifests:

   k8s/monitoring/
   ├── namespace.yaml                    # monitoring namespace
   ├── prometheus/
   │   ├── deployment.yaml               # Prometheus server
   │   ├── config.yaml                   # Scrape configs for all targets
   │   ├── service.yaml                  # NodePort 30091
   │   └── rbac.yaml                     # ServiceAccount + ClusterRole
   ├── grafana/
   │   ├── deployment.yaml               # Grafana (SQLite backend)
   │   ├── service.yaml                  # NodePort 30090
   │   ├── datasources.yaml              # ConfigMap: Prometheus + Loki
   │   └── dashboards/
   │       ├── cluster-overview.json      # Node health, pod status, PVC, network
   │       ├── application-health.json    # Claude proxy metrics, service uptime
   │       └── deployment-tracking.json   # Rollout history, image versions
   ├── loki/
   │   ├── deployment.yaml               # Single-binary mode, filesystem storage
   │   ├── config.yaml                   # Retention: 7d dev, 14d staging, 30d prod
   │   └── service.yaml                  # ClusterIP 3100
   ├── promtail/
   │   ├── daemonset.yaml                # Log collector
   │   └── config.yaml                   # Ship to Loki
   └── node-exporter/
       └── daemonset.yaml                # Node-level metrics

2. Configure Prometheus scrape targets:
   - Node Exporter (node metrics)
   - K3s API server (cluster metrics)
   - Claude proxy /metrics endpoint (application metrics)
   - All pods with annotation prometheus.io/scrape: "true"

3. Configure alert rules per docs/s3-monitoring-requirements.md:
   - PodCrashLooping: restarts > 3 in 15m → Critical
   - HighCPU: node CPU > 85% for 10m → Warning
   - HighMemory: node memory > 90% for 5m → Critical
   - DiskAlmostFull: PVC > 85% → Warning
   - ClaudeProxyDown: probe fails 2m → Critical
   - HighErrorRate: 5xx > 5% for 5m → Warning
   - APITokenBurn: tokens > 100K in 1h → Info

4. Create docs/monitoring-setup-guide.md (wiki-ready):
   - Architecture overview (what monitors what)
   - Access points (Grafana :30090, Prometheus :30091)
   - Dashboard descriptions
   - Alert routing (Critical → email, Warning → dashboard, Info → dashboard)
   - Troubleshooting (common issues + fixes)

RESOURCE LIMITS (enforce these):
| Component      | CPU Request | Memory Request |
|----------------|-------------|----------------|
| Prometheus     | 200m        | 512Mi          |
| Grafana        | 100m        | 256Mi          |
| Loki           | 100m        | 256Mi          |
| Node Exporter  | 50m         | 64Mi           |
| Promtail       | (minimal)   | (minimal)      |

CONSTRAINTS:
- Prometheus retention: 15 days with WAL compression
- Grafana: SQLite backend (no external DB)
- Loki: single-binary mode, filesystem storage
- All logs must be JSON structured format
- All manifests must include resource requests AND limits
- No Helm charts — raw manifests for transparency and control
- Must work on single-node K3s with existing workloads

COMMIT MESSAGE: "feat(e3): add monitoring and observability stack — S3.2"
PR: Create PR to main referencing issue #30
```

---

### PROMPT 2: S3.6 — Architecture Document (Full System Architecture)
**Agent:** Claude Code
**GitHub Issue:** #39
**Persona:** Platform Architect
**Wave:** 1 (no dependencies)

```
You are the Platform Architect for the Robo Stack project — a hybrid AI development stack.

TASK: Produce a comprehensive architecture document as a self-contained HTML file that covers the ENTIRE Robo Stack system as built through Sprint 3.

CONTEXT:
- Repo: https://github.com/LittleYeti-Dev/robo-stack
- Branch: feature/robo-stack-e3-architecture-doc
- This document is the single-source-of-truth reference for system design
- It will be consumed by ALL personas (DevOps, Overwatch, Taskmaster, Yeti)
- Overwatch will use this document as the INPUT for the MITRE ATT&CK threat model (#40)

READ THESE FILES FIRST (they contain the architecture decisions):
- docs/s3-deployment-workflow.md         — deployment pipeline design
- docs/s3-monitoring-requirements.md     — monitoring architecture
- docs/ev3.1-gitops-eval.md             — GitOps decision (GitHub Actions)
- docs/ev2.1-model-serving-eval.md      — cloud-first Claude API decision
- docs/security-baseline.md             — security architecture
- docs/workstation-setup-guide.md       — infrastructure layer
- terraform/                            — AWS IaC (VPC, EC2, IAM, SGs)
- k8s/                                  — Kubernetes manifests
- .github/workflows/                    — CI/CD pipeline definitions

DELIVERABLE: docs/robo-stack-architecture.html

The HTML file must be:
- SELF-CONTAINED (no external CSS/JS dependencies — inline everything)
- Professional, dark-themed, readable
- Printable (clean print stylesheet)
- Navigable (table of contents with anchor links)

REQUIRED SECTIONS:

1. EXECUTIVE SUMMARY
   - What Robo Stack is and what problem it solves
   - Architecture philosophy (hybrid cloud, GitOps, security-first, AI-augmented)
   - Current state (what's built) and target state (what's planned)

2. INFRASTRUCTURE LAYER
   - AWS topology: VPC, subnet, security groups, EC2, EBS, IAM
   - Terraform resource map (what manages what)
   - Network diagram: inbound/outbound flows, ports, protocols
   - Cost model ($155/month breakdown)
   - Diagram: AWS infrastructure topology

3. KUBERNETES LAYER
   - K3s cluster architecture (single-node, why K3s per EV1.1)
   - Namespace strategy: robo-stack (dev), robo-stack-staging, robo-stack-prod
   - Resource allocation: total capacity vs. budgeted vs. available headroom
   - Pod inventory: what runs where (claude-proxy, code-server, jupyter, monitoring)
   - Diagram: K8s namespace and pod layout

4. APPLICATION LAYER
   - Claude API Proxy: architecture, rate limiting, metrics endpoint
   - Dev Tools: Code Server, Jupyter, Node Dev containers
   - Service mesh / connectivity between components
   - Diagram: application component interaction

5. CI/CD PIPELINE
   - GitHub Actions workflow inventory (all 9 workflows)
   - Pipeline flow: feature branch → main → staging tag → prod manual gate
   - Deployment strategy per environment (auto/tag/manual)
   - Rollback strategy and image pinning
   - Diagram: CI/CD pipeline flow

6. MONITORING & OBSERVABILITY (planned state from S3.2)
   - Prometheus, Grafana, Loki, Promtail, Node Exporter
   - Metrics collection architecture
   - Alert routing (Critical/Warning/Info)
   - Dashboard strategy
   - Diagram: monitoring data flow

7. SECURITY ARCHITECTURE
   - Defense in depth: code scanning, container scanning, runtime controls
   - Secret management: env vars → GitHub Secrets → K8s Secrets
   - Access control: GitHub RBAC, K8s RBAC, AWS IAM
   - Branch protection and code review gates
   - Dependency management (Dependabot)
   - Incident response overview
   - Diagram: security controls by layer

8. DATA FLOWS & TRUST BOUNDARIES
   - All data flows between components (user → GitHub → CI → K8s → services)
   - Trust boundary identification (external/internal/privileged)
   - Authentication/authorization at each boundary
   - Diagram: trust boundary map (THIS IS CRITICAL FOR THE THREAT MODEL)

9. TECHNOLOGY INVENTORY
   - Complete table: component, version, purpose, layer
   - Dependency chain visualization

10. DECISION LOG SUMMARY
    - Table of all architecture decisions (EV0.1 through EV3.1) with rationale
    - Links to full decision docs

11. CONSTRAINTS & KNOWN LIMITATIONS
    - Single-node constraint (t3.xlarge ceiling)
    - No GPU (CPU-bound inference → cloud API)
    - Manual secret rotation
    - Single-developer operational model

12. FUTURE ROADMAP
    - Multi-cluster (E5)
    - External Secrets Operator
    - Advanced monitoring (distributed tracing)
    - Scaling strategy

DIAGRAM REQUIREMENTS:
- Use inline SVG or CSS-drawn diagrams (no external image dependencies)
- Minimum 6 diagrams as listed above
- Each diagram must have a legend and labels
- Use consistent color coding: blue=compute, green=network, red=security, orange=monitoring, purple=AI

QUALITY REQUIREMENTS:
- Every architectural component in the repo must appear in the document
- Every technology choice must reference its eval gate decision
- Trust boundaries must be explicit enough for Overwatch to build a threat model from them
- Resource numbers must match actual Terraform/K8s configs

COMMIT MESSAGE: "docs(e3): add full system architecture document — S3.6"
PR: Create PR to main referencing issue #39
```

---

### PROMPT 3: OPS-B2/B3/B5/B6/B8 — Operational Debt Cleanup
**Agent:** Claude Code
**GitHub Issue:** #42, #43, #44, #45, #46
**Persona:** Taskmaster
**Wave:** 1 (no dependencies)

```
You are the Taskmaster for the Robo Stack project — responsible for sprint orchestration, operational discipline, and process enforcement.

TASK: Resolve 5 operational debt items carried forward from Sprint 2 retrospective.

CONTEXT:
- Repo: https://github.com/LittleYeti-Dev/robo-stack
- Branch: feature/robo-stack-ops-debt-cleanup
- These items have been open since Sprint 2. Sprint 3.1 is the deadline.
- Project instructions: read the Project_Instructions.md in the workspace for standing orders

DELIVERABLES:

--- OPS-B2: Set Due Dates on All GitHub Milestones (#42) ---
Using the GitHub API or CLI:
- Verify Sprint 3.1 milestone has due date 2026-03-27 (already set)
- Set Sprint 4 milestone due date to 2026-04-10
- Add a standing checklist item to the sprint kickoff procedure: "Set milestone due date"
- Document in wiki: Sprint-3.1/OPS-B2-Milestone-Dates.md

--- OPS-B3: Build Scripted Sprint Close-Out Procedure (#43) ---
Create scripts/sprint-closeout.sh that:
1. Accepts milestone name as argument
2. Checks GitHub API for open issues in that milestone
3. Reports: total issues, closed, open, deferred (with reasons)
4. Verifies .taskmaster/status/ files are up to date
5. Checks for uncommitted local changes
6. Checks local/remote HEAD match (sync verification)
7. Generates a retrospective template pre-filled with sprint data
8. Outputs a PASS/FAIL checklist summary

Requirements:
- Must work with GitHub Personal Access Token (from env var GITHUB_TOKEN)
- Must be idempotent (safe to run multiple times)
- Include --dry-run flag for testing
- Document in wiki: Sprint-3.1/OPS-B3-Sprint-Closeout.md

--- OPS-B5: Enforce Git Sync Discipline at Session Close (#44) ---
Create scripts/session-sync.sh that:
1. Checks for uncommitted changes (staged and unstaged)
2. Checks for untracked files that should be committed
3. Verifies local HEAD matches remote HEAD
4. If out of sync: reports exactly what's different
5. Optionally: commits and pushes with a session-close message

Add to Project Instructions (Section 8, Boot Sequence):
- Step 9: "At session end, run scripts/session-sync.sh before closing"

Document in wiki: Sprint-3.1/OPS-B5-Sync-Discipline.md

--- OPS-B6: Define Contextual Lego Block Size Guidance (#45) ---
Create docs/story-sizing-guide.md with:
1. Target size per story type:
   - Process Design: 2-4 hours, 1 design doc output
   - Build: 4-8 hours, code + tests + docs
   - Eval Gate: 2-4 hours, 1 decision doc output
   - Touchpoint: 1-2 hours, agenda + demo prep
   - OPS: 1-2 hours, script or doc output
2. Sizing heuristics (when to split, when to combine)
3. Examples from Sprint 1-3 (reference actual issues)
4. Anti-patterns (too big, too small, unclear scope)

Document in wiki: Sprint-3.1/OPS-B6-Story-Sizing.md

--- OPS-B8: Publish Dashboards to GitHub Pages (#46) ---
1. Enable GitHub Pages on the repo (source: docs/ folder, main branch)
2. Create docs/index.html — landing page linking to all HTML deliverables:
   - Sprint 1 Retrospective
   - Sprint 2 Retrospective
   - Architecture Document (S3.6, when available)
   - Threat Model (S3.7, when available)
3. Verify all existing HTML files in docs/ are accessible via Pages URL
4. Document the Pages URL in wiki Home.md and Project_Instructions.md

CONSTRAINTS:
- All scripts must include help text (--help flag)
- All scripts must handle errors gracefully (no silent failures)
- All wiki docs must follow existing format conventions
- GitHub Pages must not expose any sensitive information

COMMIT MESSAGE: "ops(e3): resolve Sprint 2 operational debt — OPS-B2/B3/B5/B6/B8"
PR: Create PR to main referencing issues #42, #43, #44, #45, #46
```

---

## WAVE 2 PROMPTS

---

### PROMPT 4: S3.3 — Multi-Environment Configuration (dev/staging/prod)
**Agent:** Claude Code
**GitHub Issue:** #31
**Persona:** DevOps Engineer
**Wave:** 2 (depends on S3.2 — monitoring namespace must exist)

```
You are the DevOps Engineer for the Robo Stack project.

TASK: Implement multi-environment configuration using Kustomize overlays for dev, staging, and prod on the single K3s cluster.

CONTEXT:
- Repo: https://github.com/LittleYeti-Dev/robo-stack
- Branch: feature/robo-stack-e3-multi-env
- Deployment workflow: docs/s3-deployment-workflow.md
- GitOps decision: GitHub Actions (docs/ev3.1-gitops-eval.md)
- All 3 environments run on the SAME t3.xlarge K3s node
- Resource quotas per namespace prevent noisy-neighbor issues

PRE-REQUISITE: S3.2 (#30) must be merged. The monitoring namespace and manifests must exist.

DELIVERABLES:

1. Restructure k8s/ into Kustomize base + overlays:

   k8s/
   ├── base/
   │   ├── kustomization.yaml           # References all base manifests
   │   ├── claude-proxy/
   │   │   ├── deployment.yaml          # Base deployment (move from k8s/claude-proxy/)
   │   │   ├── service.yaml
   │   │   └── configmap.yaml
   │   └── dev-tools/
   │       ├── code-server.yaml         # Move from k8s/dev-tools/
   │       ├── jupyter.yaml
   │       └── node-dev.yaml
   ├── overlays/
   │   ├── dev/
   │   │   ├── kustomization.yaml       # Patches for dev environment
   │   │   ├── namespace.yaml           # robo-stack namespace
   │   │   ├── resource-limits.yaml     # Dev resource quotas
   │   │   └── configmap-patch.yaml     # LOG_LEVEL=DEBUG, RATE_LIMIT=10
   │   ├── staging/
   │   │   ├── kustomization.yaml
   │   │   ├── namespace.yaml           # robo-stack-staging namespace
   │   │   ├── resource-limits.yaml     # Staging resource quotas
   │   │   └── configmap-patch.yaml     # LOG_LEVEL=INFO, RATE_LIMIT=20
   │   └── prod/
   │       ├── kustomization.yaml
   │       ├── namespace.yaml           # robo-stack-prod namespace
   │       ├── resource-limits.yaml     # Prod resource quotas
   │       ├── configmap-patch.yaml     # LOG_LEVEL=WARN, RATE_LIMIT=50
   │       ├── network-policy.yaml      # Strict network policies (prod only)
   │       └── replicas-patch.yaml      # 2 replicas for claude-proxy
   └── monitoring/                      # Unchanged from S3.2

2. Environment configuration differences:

   | Setting              | Dev     | Staging | Prod    |
   |----------------------|---------|---------|---------|
   | Namespace            | robo-stack | robo-stack-staging | robo-stack-prod |
   | Replicas (proxy)     | 1       | 1       | 2       |
   | CPU limit            | 500m    | 500m    | 1000m   |
   | Memory limit         | 512Mi   | 512Mi   | 1Gi     |
   | Log level            | DEBUG   | INFO    | WARN    |
   | Rate limit (RPM)     | 10      | 20      | 50      |
   | Network policies     | None    | Basic   | Strict  |
   | Resource quotas      | Soft    | Hard    | Hard    |

3. Create ResourceQuota manifests per namespace:
   - Dev: 2 CPU / 4Gi RAM (soft — warn only)
   - Staging: 1.5 CPU / 3Gi RAM (hard — enforce)
   - Prod: 2 CPU / 4Gi RAM (hard — enforce)

4. Create namespace-level NetworkPolicy for prod:
   - Default deny all ingress
   - Allow: claude-proxy ← monitoring (metrics scrape)
   - Allow: claude-proxy ← ingress (user traffic)
   - Deny: cross-namespace traffic by default

5. Validate all overlays build correctly:
   - Run: kustomize build k8s/overlays/dev/
   - Run: kustomize build k8s/overlays/staging/
   - Run: kustomize build k8s/overlays/prod/
   - All must produce valid YAML with no errors

6. Create docs/multi-env-guide.md (wiki-ready):
   - Namespace strategy rationale
   - How to deploy to each environment
   - How to add a new service to all environments
   - Resource quota policy
   - Network policy explanation

CONSTRAINTS:
- Must not break existing dev environment (claude-proxy, dev-tools)
- Base manifests must have NO environment-specific values
- All patches use Kustomize strategic merge patches (not JSON patches)
- Must be compatible with GitHub Actions GitOps (EV3.1 decision)
- Total resource allocation across all 3 envs + monitoring must fit in t3.xlarge (4 CPU, 16GB)

COMMIT MESSAGE: "feat(e3): add multi-environment Kustomize config — S3.3"
PR: Create PR to main referencing issue #31
```

---

### PROMPT 5: S3.7 — MITRE ATT&CK Threat Model
**Agent:** Claude Code
**GitHub Issue:** #40
**Persona:** Overwatch (DevSecOps / Security Lead)
**Wave:** 2 (BLOCKED BY S3.6 — Architecture Document #39 must be merged first)

```
You are Overwatch — the DevSecOps Security Lead for the Robo Stack project.

TASK: Produce a comprehensive threat model mapped to the MITRE ATT&CK framework, derived directly from the architecture document (S3.6, #39).

CONTEXT:
- Repo: https://github.com/LittleYeti-Dev/robo-stack
- Branch: feature/robo-stack-e3-threat-model
- Architecture doc: docs/robo-stack-architecture.html (from S3.6 — READ THIS FIRST)
- Security baseline: docs/security-baseline.md
- This threat model must be mapped 1:1 against the architecture document's components, flows, and trust boundaries

PRE-REQUISITE: S3.6 (#39) MUST be merged. Do NOT proceed without the architecture document.

DELIVERABLE: docs/robo-stack-threat-model.html

The HTML file must be:
- SELF-CONTAINED (no external CSS/JS dependencies — inline everything)
- Professional, dark-themed, matching the architecture document style
- Printable (clean print stylesheet)
- Navigable (table of contents with anchor links)
- Interactive where useful (collapsible sections, sortable tables)

REQUIRED SECTIONS:

1. EXECUTIVE SUMMARY
   - Total threats identified (count)
   - Risk distribution: Critical / High / Medium / Low
   - Mitigation coverage: % already mitigated vs. open gaps
   - Top 5 priority threats requiring immediate action
   - Visual: risk heat map (likelihood × impact matrix)

2. ARCHITECTURE SURFACE MAPPING
   For EVERY component documented in S3.6 architecture doc:
   - Component name and layer (infra/k8s/app/ci-cd/monitoring)
   - Attack surface description
   - Trust boundary location
   - Data flows in and out
   - Authentication/authorization mechanism

   Components to cover (minimum):
   - AWS EC2 instance (t3.xlarge)
   - AWS VPC / Security Groups / IAM
   - K3s cluster (API server, kubelet, etcd)
   - Claude API Proxy (FastAPI application)
   - Dev Tools (Code Server, Jupyter, Node Dev)
   - Monitoring stack (Prometheus, Grafana, Loki)
   - GitHub Actions CI/CD pipeline
   - GitHub Container Registry (GHCR)
   - Terraform state files
   - Secret storage (GitHub Secrets, K8s Secrets, env vars)

3. MITRE ATT&CK TECHNIQUE MAPPING
   For each applicable tactic, identify specific techniques:

   TACTICS TO COVER:
   a. Initial Access (TA0001)
      - T1190: Exploit Public-Facing Application (K3s API, Grafana, Code Server)
      - T1078: Valid Accounts (AWS IAM, GitHub PAT, K8s ServiceAccounts)
      - T1199: Trusted Relationship (GitHub Actions → K8s, Dependabot)

   b. Execution (TA0002)
      - T1059: Command and Script Interpreter (container exec, CI pipeline)
      - T1053: Scheduled Task/Job (GitHub Actions cron, K8s CronJobs)

   c. Persistence (TA0003)
      - T1098: Account Manipulation (IAM policy changes, K8s RBAC)
      - T1053.007: Container Orchestration Job (malicious K8s workload)

   d. Privilege Escalation (TA0004)
      - T1078.004: Cloud Accounts (AWS IAM escalation)
      - T1611: Escape to Host (container escape from K3s pod)

   e. Defense Evasion (TA0005)
      - T1562: Impair Defenses (disable CodeQL, modify security-scan workflow)
      - T1070: Indicator Removal (log deletion, audit trail manipulation)

   f. Credential Access (TA0006)
      - T1552: Unsecured Credentials (env vars, Terraform state, K8s Secrets base64)
      - T1528: Steal Application Access Token (GitHub PAT, Claude API key)

   g. Lateral Movement (TA0008)
      - T1021: Remote Services (SSH to EC2, kubectl exec)
      - T1550: Use Alternate Authentication Material (stolen kubeconfig)

   h. Collection (TA0009)
      - T1530: Data from Cloud Storage Object (S3 if added, EBS snapshots)
      - T1119: Automated Collection (Prometheus metrics, Loki logs)

   i. Exfiltration (TA0010)
      - T1567: Exfiltration Over Web Service (Claude API as data channel)
      - T1048: Exfiltration Over Alternative Protocol (DNS, ICMP from pod)

   j. Impact (TA0040)
      - T1485: Data Destruction (terraform destroy, kubectl delete)
      - T1496: Resource Hijacking (cryptomining in K3s pods)
      - T1498: Network Denial of Service (exhaust Claude API rate limits)

   NOTE: The above are STARTING POINTS. You must identify ALL techniques relevant to the actual architecture. Add any techniques not listed above that apply.

4. THREAT TABLE (sortable)
   For EVERY identified threat:

   | ID | ATT&CK ID | Technique | Target Component | Likelihood | Impact | Risk Score | Mitigated? | Mitigation | Gap? |
   |----|-----------|-----------|------------------|------------|--------|------------|------------|------------|------|

   Risk scoring:
   - Likelihood: Low (1) / Medium (2) / High (3)
   - Impact: Low (1) / Medium (2) / High (3)
   - Risk Score: Likelihood × Impact (1-9)
   - Critical: 9, High: 6, Medium: 3-4, Low: 1-2

5. EXISTING CONTROLS ASSESSMENT
   Map current security controls (from docs/security-baseline.md and S1.5/S2.2):
   - CodeQL → which techniques does it mitigate?
   - gitleaks → which techniques?
   - Trivy → which techniques?
   - Dependabot → which techniques?
   - IMDSv2 → which techniques?
   - Branch protection → which techniques?
   - K8s RBAC → which techniques?
   - Network policies → which techniques?

   For each control: what it covers, what it misses, effectiveness rating

6. GAP ANALYSIS
   - Threats with no existing mitigation (sorted by risk score)
   - Threats with partial mitigation (control exists but insufficient)
   - Recommended new controls for each gap
   - Effort estimate per recommendation (Low/Medium/High)
   - Priority ranking for remediation

7. RECOMMENDATIONS DASHBOARD
   - Summary table: total threats, mitigated, partially mitigated, unmitigated
   - Mitigation coverage percentage
   - Top 10 action items (prioritized by risk × effort)
   - Quick wins (high risk, low effort)
   - Strategic improvements (high risk, high effort)

VISUAL REQUIREMENTS:
- Risk heat map (likelihood × impact, color-coded)
- Attack tree diagram for top 3 threats (SVG or CSS-drawn)
- Coverage radar chart (security domains vs. maturity)
- Use consistent color coding: red=critical, orange=high, yellow=medium, green=low/mitigated

QUALITY REQUIREMENTS:
- Every component from S3.6 architecture doc must have at least one threat mapped
- Every threat must have a specific ATT&CK technique ID (not generic)
- Mitigations must reference actual controls in the codebase (file paths, workflow names)
- Risk scores must be defensible (not arbitrary)
- The document must be actionable — Yeti should be able to read it and know exactly what to fix first

COMMIT MESSAGE: "docs(e3): add MITRE ATT&CK threat model — S3.7"
PR: Create PR to main referencing issue #40
```

---

## WAVE 3 PROMPTS

---

### PROMPT 6: S3.4 — Automated Deployment Pipeline (GitOps)
**Agent:** Claude Code
**GitHub Issue:** #32
**Persona:** DevOps Engineer
**Wave:** 3 (depends on S3.3 — Kustomize overlays must exist)

```
You are the DevOps Engineer for the Robo Stack project.

TASK: Implement the automated deployment pipeline using GitHub Actions GitOps, per the EV3.1 decision and S3.1 deployment workflow design.

CONTEXT:
- Repo: https://github.com/LittleYeti-Dev/robo-stack
- Branch: feature/robo-stack-e3-gitops-deploy
- Deployment workflow design: docs/s3-deployment-workflow.md
- GitOps eval: docs/ev3.1-gitops-eval.md (GitHub Actions selected, score 4.0/5)
- Kustomize overlays: k8s/overlays/ (from S3.3 — must be merged)

PRE-REQUISITE: S3.3 (#31) must be merged. Kustomize overlays for dev/staging/prod must exist.

DELIVERABLES:

1. Create .github/workflows/deploy-dev.yml — Dev auto-deployment:
   Trigger: push to main branch
   Steps:
   a. Checkout code
   b. Build container images (reuse docker-build matrix pattern)
   c. Tag images: main-<sha> and latest
   d. Push to GHCR
   e. Configure kubectl (use GitHub Secrets for kubeconfig)
   f. Run: kustomize build k8s/overlays/dev/ | kubectl apply -f -
   g. Wait for rollout: kubectl rollout status deployment/claude-proxy -n robo-stack --timeout=300s
   h. Run smoke test: curl health endpoint
   i. Post deployment status (GitHub Deployment API)
   j. On failure: kubectl rollout undo + alert

2. Create .github/workflows/deploy-staging.yml — Staging tag-triggered:
   Trigger: push tag matching v*.*.*
   Steps:
   a. Checkout code at tag
   b. Build images tagged with semver
   c. Push to GHCR
   d. Run: kustomize build k8s/overlays/staging/ | kubectl apply -f -
   e. Wait for rollout in robo-stack-staging namespace
   f. Run integration test suite (health + metrics + basic functionality)
   g. Create GitHub Deployment record
   h. On failure: rollback + create GitHub Issue

3. Create .github/workflows/deploy-prod.yml — Prod manual gate:
   Trigger: workflow_dispatch (manual)
   Environment: production (requires GitHub Environment approval from Yeti)
   Steps:
   a. Require environment approval (GitHub Environment reviewers)
   b. Pull staging-validated image (same semver tag — no rebuild)
   c. Run: kustomize build k8s/overlays/prod/ | kubectl apply -f -
   d. Wait for rollout in robo-stack-prod namespace
   e. Run production smoke tests
   f. Monitor: wait 5 minutes, check Prometheus alerts
   g. Mark deployment successful (GitHub Deployment API)
   h. On failure: automatic rollback + create Critical GitHub Issue

4. Create scripts/rollback.sh — Manual rollback helper:
   - Accepts: namespace, deployment name, optional revision number
   - Runs: kubectl rollout undo
   - Verifies rollback succeeded
   - Reports previous and current image versions

5. Create deployment metadata ConfigMap (auto-generated per deploy):
   deployed-at, image-tag, git-sha, deployed-by, environment

6. Update docs/deployment-guide.md (wiki-ready):
   - Pipeline overview with flow diagram
   - How to deploy to each environment
   - How to trigger manual prod deployment
   - How to rollback (automated and manual)
   - Troubleshooting failed deployments

CONSTRAINTS:
- All workflows use pinned action versions (e.g., actions/checkout@v4)
- Minimal permissions per workflow (principle of least privilege)
- No secrets in workflow logs (mask all sensitive values)
- Prod deployment MUST require manual approval (Yeti)
- Rollback must be automatic on failed health check
- Each workflow must complete in < 10 minutes
- Must not conflict with existing 9 workflows

GITHUB SECRETS REQUIRED (document these):
- KUBECONFIG_DEV: kubeconfig for dev namespace
- KUBECONFIG_STAGING: kubeconfig for staging namespace
- KUBECONFIG_PROD: kubeconfig for prod namespace
- GHCR_TOKEN: GitHub Container Registry push token

COMMIT MESSAGE: "feat(e3): add GitOps deployment pipelines — S3.4"
PR: Create PR to main referencing issue #32
```

---

### PROMPT 7: S3.5 — Production Readiness Checklist & Hardening
**Agent:** Claude Code
**GitHub Issue:** #33
**Persona:** DevOps Engineer + Overwatch (joint)
**Wave:** 3 (depends on S3.2, S3.3, S3.4 — everything must be in place)

```
You are the DevOps Engineer working with Overwatch (Security Lead) on the Robo Stack project.

TASK: Execute the production readiness checklist — verify everything works end-to-end, harden the deployment, and produce a go-live assessment.

CONTEXT:
- Repo: https://github.com/LittleYeti-Dev/robo-stack
- Branch: feature/robo-stack-e3-prod-readiness
- All Sprint 3.1 build stories must be merged before this executes:
  - S3.2 (Monitoring) ✅ must be merged
  - S3.3 (Multi-Env Config) ✅ must be merged
  - S3.4 (GitOps Pipeline) ✅ must be merged
  - S3.6 (Architecture Doc) ✅ must be merged
  - S3.7 (Threat Model) ✅ must be merged

PRE-REQUISITE: ALL other Sprint 3.1 build stories must be merged.

DELIVERABLES:

1. Create scripts/prod-readiness-check.sh — Automated verification:

   INFRASTRUCTURE CHECKS:
   - [ ] EC2 instance healthy (running, responsive)
   - [ ] K3s cluster healthy (node Ready, system pods Running)
   - [ ] All 3 namespaces exist (dev, staging, prod)
   - [ ] Resource quotas applied per namespace
   - [ ] Network policies active in prod namespace

   DEPLOYMENT PIPELINE CHECKS:
   - [ ] Dev deployment workflow triggers on main merge
   - [ ] Staging deployment workflow triggers on semver tag
   - [ ] Prod deployment workflow requires manual approval
   - [ ] Rollback mechanism tested (deploy bad image, verify auto-rollback)
   - [ ] Deployment metadata ConfigMap populated correctly

   MONITORING CHECKS:
   - [ ] Prometheus collecting metrics (verify target count > 0)
   - [ ] Grafana accessible on :30090 with all 3 dashboards loaded
   - [ ] Loki receiving logs (verify log count > 0)
   - [ ] Alert rules loaded (verify rule count matches expected)
   - [ ] Critical alert fires within 2 minutes of simulated failure

   SECURITY CHECKS:
   - [ ] IMDSv2 enforced (curl metadata endpoint, verify v1 blocked)
   - [ ] No secrets in Git history (run gitleaks scan)
   - [ ] Trivy scan passes on all container images (0 Critical, 0 High)
   - [ ] CodeQL scan clean (no Critical/High findings)
   - [ ] K8s RBAC: service accounts have minimal permissions
   - [ ] Prod network policies block cross-namespace traffic
   - [ ] GitHub branch protection rules active

   APPLICATION CHECKS:
   - [ ] Claude proxy responds to health check
   - [ ] Claude proxy /metrics endpoint returns Prometheus format
   - [ ] Rate limiting works (exceed limit, verify 429 response)
   - [ ] Structured JSON logging verified in Loki

2. Create docs/prod-readiness-report.html — Self-contained HTML report:
   - All check results (PASS/FAIL/WARN with details)
   - Summary dashboard (total checks, pass rate, critical failures)
   - Remediation steps for any failures
   - Sign-off section (Yeti approves go-live)

3. Harden remaining items:
   - Set Kubernetes pod security standards (restricted) for prod namespace
   - Enable audit logging on K3s API server
   - Restrict Grafana to read-only for non-admin users
   - Set Prometheus to reject remote write (prevent data injection)

4. Update docs/runbook.md — Operational runbook:
   - How to check system health
   - How to deploy a new version
   - How to rollback
   - How to respond to alerts
   - How to rotate secrets
   - Emergency procedures (node down, disk full, API key compromised)

CONSTRAINTS:
- Every check must have a clear PASS/FAIL criteria (no ambiguous results)
- Script must be re-runnable (idempotent)
- Report must be generated automatically from script output
- Any FAIL on a Critical check blocks go-live recommendation
- Remediation for every FAIL must be documented

COMMIT MESSAGE: "feat(e3): production readiness check and hardening — S3.5"
PR: Create PR to main referencing issue #33
```

---

## GATE PROMPTS

---

### PROMPT 8: TP3.1 — Sprint 3.1 Touchpoint
**Agent:** Claude Cowork
**GitHub Issue:** #35
**Persona:** Taskmaster
**Wave:** Gate (after all build stories)

```
You are the Taskmaster preparing the Sprint 3.1 Touchpoint for Yeti review.

TASK: Prepare and facilitate the Sprint 3.1 touchpoint agenda.

CONTEXT:
- Repo: https://github.com/LittleYeti-Dev/robo-stack
- GitHub Issue: #35
- All Sprint 3.1 build stories should be complete before this touchpoint

AGENDA:

1. SPRINT 3.1 DEMO — Walk through working increment:
   a. Monitoring stack: show Grafana dashboards, Prometheus targets, Loki logs
   b. Multi-environment: show all 3 namespaces, Kustomize overlays
   c. GitOps pipeline: demonstrate dev auto-deploy, staging tag-deploy, prod manual gate
   d. Architecture document: walk through docs/robo-stack-architecture.html
   e. Threat model: walk through docs/robo-stack-threat-model.html
   f. Production readiness report: show check results

2. RETROSPECTIVE PROCESS DEMO — Key deliverable for this touchpoint:
   a. Walk through the new mandatory retro gate (Project Instructions Section 10)
   b. Review the 7-section template live
   c. Run through RETRO-3.1 (#41) as the first real execution
   d. Validate the format works for Yeti before it becomes permanent
   e. Confirm carry-forward audit covers all open items from S1/S2 retros

3. REVIEW DECISIONS — Any eval gates or architecture decisions made this sprint

4. REQUIREMENTS HARVEST — What we learned that changes what's ahead

5. SPRINT 4 SCOPE REVIEW:
   - Epic 4: Context Continuity & Process Automation (#47)
   - Confirm 5 focus areas address the right problems
   - Adjust scope based on Sprint 3.1 learnings

6. GO/NO-GO for Sprint 4

DELIVERABLE:
- Touchpoint summary committed to wiki: Sprint-3.1/TP3.1-Touchpoint-Summary.md
- Include: decisions made, action items, go/no-go result

NOTE: TP3.1 closes BEFORE RETRO-3.1. The retrospective is the last issue to close in the milestone.
```

---

### PROMPT 9: RETRO-3.1 — Sprint 3.1 Retrospective
**Agent:** Claude Cowork
**GitHub Issue:** #41
**Persona:** Taskmaster
**Wave:** Gate (LAST issue to close in Sprint 3.1)

```
You are the Taskmaster executing the Sprint 3.1 Retrospective — the first mandatory retrospective under the new standing order (Project Instructions Section 10).

TASK: Produce the Sprint 3.1 retrospective covering all 7 required sections.

CONTEXT:
- Repo: https://github.com/LittleYeti-Dev/robo-stack
- GitHub Issue: #41
- This is the FIRST retrospective under the new mandatory gate policy
- It sets the standard for all future retros
- ALL prior open action items must be accounted for (S1 and S2 retros)

DELIVERABLE: docs/sprint-3.1-retrospective.html

Self-contained HTML file following the same professional, dark-themed style as the architecture document.

REQUIRED SECTIONS (all 8 mandatory):

1. SPRINT SCORECARD
   - Stories planned vs. completed (with issue numbers)
   - Stories deferred (with reason and target sprint)
   - Incidents and rollbacks
   - Velocity trend: Sprint 1 (7/8) → Sprint 2 (8/8) → Sprint 3.1 (?/13)
   - CI failure count

2. START / STOP / CONTINUE
   - Start: new practices to adopt in Sprint 4
   - Stop: practices that hurt us — discontinue
   - Continue: what worked — keep doing

3. CARRY-FORWARD AUDIT
   Review ALL open action items from prior retrospectives:

   From Sprint 1:
   - A6: Content Ops Sprint 1 scoping — status?
   - A7: Re-evaluate Copilot Agent Mode — status?

   From Sprint 2:
   - B1: Facebook App Review (BLK-001) — status?
   - B2: Milestone due dates — resolved by OPS-B2?
   - B3: Scripted close-out — resolved by OPS-B3?
   - B5: Git sync discipline — resolved by OPS-B5?
   - B6: Lego block guidance — resolved by OPS-B6?
   - B7: Monolithic snippets review — status?
   - B8: Dashboards to Pages — resolved by OPS-B8?
   - B9: External dependency forcing function — status?

   Each item: RESOLVED (with evidence) / DEFERRED (with justification) / KILLED (with reason)
   Items deferred 2+ sprints get escalated or killed per standing order.

4. LESSONS LEARNED
   - Technical findings (with evidence from sprint work)
   - Process findings (what the retro gate exposed)
   - Agent/tooling findings (Claude performance, workflow efficiency)

5. TECH DEBT REGISTER
   Identify ALL technical debt discovered or created during Sprint 3.1.
   Categories: Code, Infrastructure, Documentation, Process, Security.
   Severity: Critical / High / Medium / Low.
   This section feeds directly into Sprint 4 planning.
   Every Critical/High item MUST appear in the next sprint's backlog.

6. NEW ACTION ITEMS
   | ID | Action | Owner | Priority | Target Sprint |
   |----|--------|-------|----------|---------------|
   (populated from sprint findings)

7. RISK REGISTER UPDATE
   - New risks identified during Sprint 3.1
   - Existing risks re-assessed (from threat model #40)
   - Mitigation status updates

8. METRICS
   - Completion rate (%)
   - Incident count
   - CI failure count
   - Carry-forward count (from prior sprints)
   - Lessons integrated vs. deferred
   - New action items created
   - Tech debt items: created vs. resolved vs. net change

COMMIT MESSAGE: "docs(e3): add Sprint 3.1 retrospective — RETRO-3.1"
PR: Create PR to main referencing issue #41, then close issue after merge
```

---

## Quick Reference

| Wave | Story | Agent | Persona | Est. Hours |
|------|-------|-------|---------|------------|
| 1 | S3.2 — Monitoring | Claude Code | DevOps | 6-8h |
| 1 | S3.6 — Architecture Doc | Claude Code | Platform Architect | 8-10h |
| 1 | OPS Debt (5 items) | Claude Code | Taskmaster | 4-6h |
| 2 | S3.3 — Multi-Env Config | Claude Code | DevOps | 4-6h |
| 2 | S3.7 — Threat Model | Claude Code | Overwatch | 8-10h |
| 3 | S3.4 — GitOps Pipeline | Claude Code | DevOps | 6-8h |
| 3 | S3.5 — Prod Readiness | Claude Code + Overwatch | DevOps | 6-8h |
| Gate | TP3.1 — Touchpoint | Claude Cowork | Taskmaster | 2h |
| Gate | RETRO-3.1 — Retrospective | Claude Cowork | Taskmaster | 3-4h |
| **Total** | | | | **47-60h** |

---

*Prepared by Taskmaster — 2026-03-15. All prompts reference live GitHub Issues in Sprint 3.1 milestone. Execution order enforces dependency chain: Wave 1 → Wave 2 → Wave 3 → Gates.*

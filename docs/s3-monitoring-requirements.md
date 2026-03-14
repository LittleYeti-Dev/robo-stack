# Sprint 3 — Monitoring & Observability Requirements

**Story:** S3.1 — Process Design (requirements) → S3.2 — Build (implementation)
**Epic:** E3 — Hybrid Cloud Deployment
**Author:** Claude (Cowork)

---

## 1. Monitoring Stack

| Component | Tool | Purpose |
|-----------|------|---------|
| Metrics | Prometheus | Cluster and application metrics collection |
| Visualization | Grafana | Dashboards, alerts, annotations |
| Logging | Loki (or stdout + kubectl logs) | Centralized log aggregation |
| Alerting | Grafana Alerting (or Alertmanager) | Incident notification |

### Resource Budget (t3.xlarge: 4 vCPU, 16 GB RAM)

| Component | CPU Request | Memory Request | Notes |
|-----------|-------------|----------------|-------|
| Prometheus | 200m | 512Mi | 15-day retention, WAL compression |
| Grafana | 100m | 256Mi | SQLite backend (no external DB) |
| Loki | 100m | 256Mi | Single-binary mode, filesystem storage |
| Node Exporter | 50m | 64Mi | DaemonSet (1 pod on single node) |
| **Total** | **450m** | **1088Mi** | ~11% CPU, ~7% RAM of node |

> Fits within the remaining capacity after dev workloads. Resource quotas per namespace enforce limits.

## 2. Metrics Requirements

### 2.1 Cluster Metrics (via kube-state-metrics + node-exporter)

- Node CPU/memory/disk utilization
- Pod status (Running, Pending, CrashLoopBackOff, OOMKilled)
- Pod restart count
- PVC usage (% full)
- Container resource usage vs limits
- K3s API server latency

### 2.2 Application Metrics (via Prometheus scrape)

**Claude Proxy (`/metrics` endpoint — already exists):**
- `claude_proxy_requests_total` — counter by status code
- `claude_proxy_request_duration_seconds` — histogram
- `claude_proxy_tokens_used_total` — counter (input/output)
- `claude_proxy_rate_limit_remaining` — gauge
- `claude_proxy_api_errors_total` — counter by error type

**Code Server / Jupyter (basic):**
- Up/down status (probe-based)
- Connection count (if exposed)

### 2.3 CI/CD Metrics (GitHub Actions)

- Workflow run duration
- Success/failure rate per workflow
- Deployment frequency (to each environment)

> CI/CD metrics collected via GitHub API polling or webhook-based approach (future enhancement).

## 3. Dashboard Requirements

### Dashboard 1: Cluster Overview
- Node health (CPU, memory, disk)
- Pod status grid (all namespaces)
- PVC usage
- Network I/O

### Dashboard 2: Application Health
- Claude proxy request rate and latency (p50, p95, p99)
- Error rate (4xx, 5xx)
- Token usage over time
- Service uptime (code-server, jupyter, node-dev)

### Dashboard 3: Deployment Tracking
- Deployment annotations on all panels
- Rollout status history
- Image version per service
- Environment comparison (dev vs staging vs prod)

## 4. Alert Rules

| Alert | Condition | Severity | Action |
|-------|-----------|----------|--------|
| PodCrashLooping | restarts > 3 in 15m | Critical | Notify immediately |
| HighCPU | node CPU > 85% for 10m | Warning | Investigate workloads |
| HighMemory | node memory > 90% for 5m | Critical | Scale down or evict |
| DiskAlmostFull | PVC > 85% used | Warning | Expand or clean up |
| ClaudeProxyDown | probe fails for 2m | Critical | Check pod logs |
| HighErrorRate | 5xx rate > 5% for 5m | Warning | Check proxy + API |
| APITokenBurn | tokens > 100K in 1h | Info | Review usage patterns |

### Alert Routing
- **Critical:** Email to Yeti (via Grafana notification channel)
- **Warning:** Dashboard annotation + email digest
- **Info:** Dashboard annotation only

## 5. Log Aggregation

### Strategy: Loki (lightweight)

**Why Loki over ELK/EFK:**
- Single binary, minimal resource footprint
- Native Grafana integration (LogQL in same dashboards)
- Indexes labels only (not full text) — fits t3.xlarge constraints
- No JVM dependency

### Log Retention
- Dev namespace: 7 days
- Staging namespace: 14 days
- Prod namespace: 30 days

### Structured Logging Standard
All application logs MUST use JSON format:
```json
{
  "timestamp": "2026-03-13T12:00:00Z",
  "level": "INFO",
  "service": "claude-proxy",
  "message": "Request completed",
  "request_id": "abc-123",
  "duration_ms": 450,
  "status_code": 200
}
```

## 6. Deployment Manifests Location

All monitoring manifests go under `k8s/monitoring/`:
```
k8s/monitoring/
├── namespace.yaml           # monitoring namespace
├── prometheus/
│   ├── deployment.yaml
│   ├── config.yaml          # scrape configs
│   ├── service.yaml
│   └── rbac.yaml            # ServiceAccount + ClusterRole
├── grafana/
│   ├── deployment.yaml
│   ├── service.yaml         # NodePort for browser access
│   ├── dashboards/          # JSON dashboard definitions
│   └── datasources.yaml     # Prometheus + Loki
├── loki/
│   ├── deployment.yaml
│   ├── config.yaml
│   └── service.yaml
├── promtail/
│   ├── daemonset.yaml       # Log collector
│   └── config.yaml
└── node-exporter/
    └── daemonset.yaml
```

## 7. Access

| Tool | Access Method | Port |
|------|--------------|------|
| Grafana | NodePort | 30090 |
| Prometheus UI | NodePort | 30091 |
| Loki (API only) | ClusterIP | 3100 |

Grafana is the single pane of glass — all monitoring accessed through it.

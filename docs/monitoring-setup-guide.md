# Monitoring & Observability Setup Guide

## Architecture Overview

The Robo Stack monitoring stack runs entirely self-hosted on the K3s cluster in the `monitoring` namespace.

```
┌─────────────────────────────────────────────────────────┐
│  K3s Node (t3.xlarge)                                   │
│                                                         │
│  ┌─────────────┐    scrape    ┌──────────────────┐      │
│  │ Prometheus   │◄────────────│ Node Exporter     │      │
│  │ :30091       │             │ (DaemonSet)       │      │
│  │              │◄──────┐     └──────────────────┘      │
│  └──────┬───────┘       │                               │
│         │               │     ┌──────────────────┐      │
│         │ datasource    ├─────│ Claude Proxy      │      │
│         ▼               │     │ /metrics          │      │
│  ┌─────────────┐        │     └──────────────────┘      │
│  │ Grafana      │        │                               │
│  │ :30090       │        │     ┌──────────────────┐      │
│  │              │        └─────│ K3s API Server    │      │
│  └──────┬───────┘              └──────────────────┘      │
│         │ datasource                                     │
│         ▼               push   ┌──────────────────┐      │
│  ┌─────────────┐   ◄──────────│ Promtail          │      │
│  │ Loki         │              │ (DaemonSet)       │      │
│  │ :3100        │              └──────────────────┘      │
│  └─────────────┘                                         │
└─────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component     | Role                              | Resource Budget         |
|---------------|-----------------------------------|-------------------------|
| Prometheus    | Metrics collection & alerting     | 200m CPU / 512Mi RAM    |
| Grafana       | Visualization & dashboards        | 100m CPU / 256Mi RAM    |
| Loki          | Log aggregation                   | 100m CPU / 256Mi RAM    |
| Promtail      | Log shipping (DaemonSet)          | 25m CPU / 32Mi RAM      |
| Node Exporter | Node-level metrics (DaemonSet)    | 50m CPU / 64Mi RAM      |

## Access Points

| Service    | URL                          | Port      |
|------------|------------------------------|-----------|
| Grafana    | `http://<node-ip>:30090`     | NodePort  |
| Prometheus | `http://<node-ip>:30091`     | NodePort  |
| Loki       | `loki.monitoring.svc:3100`   | ClusterIP |

### Grafana Login

- Default admin: `admin` / password from `grafana-admin` Secret
- Create the secret before first deploy:
  ```bash
  kubectl create secret generic grafana-admin \
    --from-literal=password=<your-password> \
    -n monitoring
  ```

## Dashboards

### 1. Cluster Overview (`robo-cluster-overview`)
- **Node CPU/Memory**: Real-time percentage usage with warning/critical thresholds
- **Pods by Status**: Running, Pending, Failed, Succeeded counts
- **PVC Usage**: Bar gauge showing percentage used per persistent volume
- **Network I/O**: Receive/transmit bytes per second per interface

### 2. Application Health (`robo-app-health`)
- **Request Rate**: Requests per second to Claude proxy
- **Latency**: p50, p95, p99 response time histograms
- **Error Rate**: 5xx error percentage with thresholds
- **Service Uptime**: UP/DOWN status indicator
- **Token Usage**: API tokens consumed per hour
- **Active Connections**: Current connection count

### 3. Deployment Tracking (`robo-deploy-tracking`)
- **Replicas**: Desired vs available replica counts per deployment
- **Updated Replicas**: Rollout progress tracking
- **Container Images**: Table of running image versions per pod
- **Pod Restarts**: Restart count trends (detect crash loops)
- **Deployment Metadata**: ConfigMap info from deploy pipeline

## Alert Rules

| Alert             | Condition                        | Severity | For    |
|-------------------|----------------------------------|----------|--------|
| PodCrashLooping   | Restarts > 3 in 15 min          | Critical | 0m     |
| HighCPU           | Node CPU > 85%                   | Warning  | 10m    |
| HighMemory        | Node memory > 90%                | Critical | 5m     |
| DiskAlmostFull    | PVC > 85%                        | Warning  | 5m     |
| ClaudeProxyDown   | Probe fails                      | Critical | 2m     |
| HighErrorRate     | 5xx > 5%                         | Warning  | 5m     |
| APITokenBurn      | Tokens > 100K in 1h             | Info     | 0m     |

### Alert Routing

| Severity | Destination                          |
|----------|--------------------------------------|
| Critical | Email notification + Grafana dashboard |
| Warning  | Grafana dashboard                    |
| Info     | Grafana dashboard                    |

## Deployment

```bash
# Deploy the full monitoring stack
kubectl apply -f k8s/monitoring/namespace.yaml
kubectl apply -f k8s/monitoring/prometheus/
kubectl apply -f k8s/monitoring/grafana/
kubectl apply -f k8s/monitoring/loki/
kubectl apply -f k8s/monitoring/promtail/
kubectl apply -f k8s/monitoring/node-exporter/
```

## Troubleshooting

### Prometheus not scraping targets
```bash
# Check target status
curl http://<node-ip>:30091/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Verify RBAC
kubectl auth can-i list pods --as=system:serviceaccount:monitoring:prometheus
```

### Grafana dashboards not loading
```bash
# Check provisioning logs
kubectl logs -n monitoring deployment/grafana | grep -i provision

# Verify ConfigMaps mounted
kubectl exec -n monitoring deployment/grafana -- ls /var/lib/grafana/dashboards/
```

### Loki not receiving logs
```bash
# Check Loki readiness
curl http://loki.monitoring.svc:3100/ready

# Check Promtail push errors
kubectl logs -n monitoring daemonset/promtail | grep -i error

# Verify Promtail can reach Loki
kubectl exec -n monitoring daemonset/promtail -- wget -qO- http://loki.monitoring.svc:3100/ready
```

### High memory usage on Prometheus
```bash
# Check current memory
kubectl top pod -n monitoring -l app=prometheus

# Reduce retention if needed (edit deployment args)
# --storage.tsdb.retention.time=7d

# Check number of active time series
curl http://<node-ip>:30091/api/v1/status/tsdb | jq '.data.headStats'
```

### Alerts not firing
```bash
# Check alert rules are loaded
curl http://<node-ip>:30091/api/v1/rules | jq '.data.groups[].rules[] | {name: .name, state: .state}'

# Check Alertmanager config (if configured)
curl http://<node-ip>:30091/api/v1/alertmanagers
```

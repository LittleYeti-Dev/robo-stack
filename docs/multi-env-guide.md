# Multi-Environment Configuration Guide

## Overview

Robo Stack runs three environments (dev, staging, prod) on a single K3s node using Kubernetes namespace isolation and Kustomize overlays.

## Namespace Strategy

| Environment | Namespace            | Purpose                              |
|-------------|----------------------|--------------------------------------|
| Dev         | `robo-stack`         | Active development and testing       |
| Staging     | `robo-stack-staging` | Pre-production validation            |
| Prod        | `robo-stack-prod`    | Production workloads                 |

All three share the same t3.xlarge node (4 vCPU, 16GB RAM). ResourceQuotas prevent any single environment from consuming all resources.

## Directory Structure

```
k8s/
├── base/                          # Environment-agnostic manifests
│   ├── kustomization.yaml
│   ├── claude-proxy/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── configmap.yaml
│   └── dev-tools/
│       ├── code-server.yaml
│       ├── jupyter.yaml
│       └── node-dev.yaml
├── overlays/
│   ├── dev/                       # Dev-specific patches
│   ├── staging/                   # Staging-specific patches
│   └── prod/                      # Prod-specific patches + hardening
└── monitoring/                    # Monitoring stack (independent)
```

## Environment Configuration Differences

| Setting              | Dev      | Staging  | Prod     |
|----------------------|----------|----------|----------|
| Namespace            | robo-stack | robo-stack-staging | robo-stack-prod |
| Replicas (proxy)     | 1        | 1        | 2        |
| CPU limit            | 500m     | 500m     | 1000m    |
| Memory limit         | 512Mi    | 512Mi    | 1Gi      |
| Log level            | DEBUG    | INFO     | WARN     |
| Rate limit (RPM)     | 10       | 20       | 50       |
| Network policies     | None     | None     | Strict   |
| Resource quotas      | Generous | Hard     | Hard     |

## Deploying to Each Environment

```bash
# Dev
kustomize build k8s/overlays/dev/ | kubectl apply -f -

# Staging
kustomize build k8s/overlays/staging/ | kubectl apply -f -

# Prod
kustomize build k8s/overlays/prod/ | kubectl apply -f -
```

Verify deployment:
```bash
kubectl get all -n <namespace>
```

## Adding a New Service

1. Create base manifests in `k8s/base/<service-name>/`:
   - `deployment.yaml` — no environment-specific values
   - `service.yaml`
   - Any ConfigMaps with sensible defaults

2. Add to `k8s/base/kustomization.yaml`:
   ```yaml
   resources:
     - <service-name>/deployment.yaml
     - <service-name>/service.yaml
   ```

3. Add environment patches in each overlay if the service needs different config per env.

4. Validate all overlays still build:
   ```bash
   kustomize build k8s/overlays/dev/
   kustomize build k8s/overlays/staging/
   kustomize build k8s/overlays/prod/
   ```

## Resource Quota Policy

| Environment | CPU Requests | Memory Requests | CPU Limits | Memory Limits |
|-------------|-------------|-----------------|------------|---------------|
| Dev         | 2 cores     | 4Gi             | 3 cores    | 6Gi           |
| Staging     | 1.5 cores   | 3Gi             | 2 cores    | 4Gi           |
| Prod        | 2 cores     | 4Gi             | 3 cores    | 6Gi           |
| Monitoring  | ~475m       | ~1088Mi         | ~1000m     | ~1792Mi       |

Total budget fits within t3.xlarge (4 vCPU, 16GB RAM) because not all environments run at full quota simultaneously during development.

## Network Policies (Prod)

Production has strict network controls:

1. **Default deny**: All ingress traffic is denied by default
2. **Monitoring scrape**: Prometheus in the `monitoring` namespace can scrape metrics on port 8080
3. **Ingress traffic**: The ingress controller (kube-system) can route user traffic to claude-proxy on port 8080
4. **Cross-namespace**: All other cross-namespace traffic is blocked

Dev and staging have no network policies for ease of development.

## Validation

After any changes, verify all overlays produce valid YAML:

```bash
for env in dev staging prod; do
  echo "=== $env ==="
  kustomize build k8s/overlays/$env/ > /dev/null && echo "OK" || echo "FAILED"
done
```

# Robo Stack -- Operational Runbook

**Project:** Robo Stack (Hybrid AI Development Stack)
**Repo:** github.com/LittleYeti-Dev/robo-stack
**Maintained by:** DevSecOps Engineer + Overwatch (Security Lead)
**Last updated:** 2026-03-15

---

## Table of Contents

1. [System Health Checks](#1-system-health-checks)
2. [Deploying a New Version](#2-deploying-a-new-version)
3. [Rollback Procedures](#3-rollback-procedures)
4. [Alert Response Procedures](#4-alert-response-procedures)
5. [Secret Rotation Procedures](#5-secret-rotation-procedures)
6. [Emergency Procedures](#6-emergency-procedures)

---

## 1. System Health Checks

### 1.1 Node Health

```bash
# Ping the EC2 node
ping -c 3 $NODE_HOST

# SSH and check system load
ssh ubuntu@$NODE_HOST "uptime && free -h && df -h"

# Check K3s service status
ssh ubuntu@$NODE_HOST "sudo systemctl status k3s"
```

**What to look for:**
- Load average below number of CPU cores
- Memory usage below 85%
- Disk usage below 80% on all partitions
- K3s service active (running)

### 1.2 Kubernetes Cluster Health

```bash
# Node status -- all should be "Ready"
kubectl get nodes -o wide

# System pods -- all should be "Running"
kubectl get pods -n kube-system

# All project pods
kubectl get pods -n robo-stack-prod -o wide
kubectl get pods -n robo-stack-staging -o wide
kubectl get pods -n robo-stack -o wide

# Recent events (look for warnings or errors)
kubectl get events -n robo-stack-prod --sort-by='.lastTimestamp' | tail -20

# Resource usage
kubectl top nodes
kubectl top pods -n robo-stack-prod
```

**What to look for:**
- All nodes in Ready state
- No pods in CrashLoopBackOff, ImagePullBackOff, or Pending
- No recurring warning events
- Resource usage within defined quotas

### 1.3 Monitoring Stack Health

```bash
# Prometheus
curl -s http://localhost:9090/-/healthy
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'

# Grafana
curl -s http://localhost:30090/api/health

# Loki
curl -s http://localhost:3100/ready

# Check alert status
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | {name: .labels.alertname, state: .state}'
```

### 1.4 Application Health

```bash
# Claude proxy health
curl -s http://localhost:8080/health

# Claude proxy metrics
curl -s http://localhost:8080/metrics | head -20
```

### 1.5 Automated Check

```bash
# Run the full production readiness check suite
./scripts/prod-readiness-check.sh

# Output results to a specific file
./scripts/prod-readiness-check.sh --json-out /tmp/readiness-$(date +%Y%m%d).json
```

---

## 2. Deploying a New Version

### 2.1 Deploy to Dev

**Trigger:** Push to `develop` branch or manual workflow dispatch.

```bash
# Automated (GitHub Actions)
git checkout develop
git pull origin develop
git push origin develop
# deploy-dev.yml triggers automatically

# Manual trigger
gh workflow run deploy-dev.yml --ref develop
```

**Verification:**
```bash
kubectl get pods -n robo-stack -l app=claude-proxy
kubectl logs -n robo-stack -l app=claude-proxy --tail=20
curl -s http://<dev-endpoint>/health
```

### 2.2 Deploy to Staging

**Trigger:** Push to `staging` branch or manual workflow dispatch after dev verification.

```bash
# Promote from develop to staging
git checkout staging
git merge develop
git push origin staging
# deploy-staging.yml triggers automatically

# Manual trigger
gh workflow run deploy-staging.yml --ref staging
```

**Verification:**
```bash
kubectl get pods -n robo-stack-staging -l app=claude-proxy
kubectl rollout status deployment/claude-proxy -n robo-stack-staging --timeout=120s
curl -s http://<staging-endpoint>/health
```

### 2.3 Deploy to Production

**Trigger:** Manual workflow dispatch only. Requires approval.

**Pre-deployment checklist:**
1. Staging has been running the same image for at least 24 hours
2. All monitoring checks are green
3. `prod-readiness-check.sh` returns GO
4. Runbook is up to date
5. On-call engineer is identified and available

```bash
# Manual trigger with the specific image tag
gh workflow run deploy-prod.yml \
  --ref main \
  -f image_tag=v1.2.3 \
  -f deployer=$(whoami)

# Monitor the rollout
kubectl rollout status deployment/claude-proxy -n robo-stack-prod --timeout=300s

# Verify
kubectl get pods -n robo-stack-prod -l app=claude-proxy
curl -s http://<prod-endpoint>/health
```

**Post-deployment:**
```bash
# Verify metrics are flowing
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.namespace=="robo-stack-prod")'

# Check for errors in logs (first 5 minutes)
kubectl logs -n robo-stack-prod -l app=claude-proxy --since=5m | grep -i error

# Update deployment metadata ConfigMap
kubectl create configmap deploy-metadata -n robo-stack-prod \
  --from-literal=git-sha=$(git rev-parse HEAD) \
  --from-literal=timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --from-literal=deployer=$(whoami) \
  --from-literal=image-tag=v1.2.3 \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

## 3. Rollback Procedures

### 3.1 Automated Rollback (Pipeline)

The deploy-prod.yml workflow includes a rollback step triggered on deployment failure.

```bash
# GitHub Actions will automatically:
# 1. Detect failed health checks after deployment
# 2. Run kubectl rollout undo
# 3. Notify via GitHub Actions notification
```

### 3.2 Manual Rollback via Script

```bash
# Quick rollback to previous revision
./scripts/rollback.sh --namespace robo-stack-prod --deployment claude-proxy

# Rollback to a specific revision
./scripts/rollback.sh --namespace robo-stack-prod --deployment claude-proxy --revision 3
```

### 3.3 Manual Rollback via kubectl

```bash
# View rollout history
kubectl rollout history deployment/claude-proxy -n robo-stack-prod

# Rollback to previous revision
kubectl rollout undo deployment/claude-proxy -n robo-stack-prod

# Rollback to a specific revision
kubectl rollout undo deployment/claude-proxy -n robo-stack-prod --to-revision=3

# Monitor the rollback
kubectl rollout status deployment/claude-proxy -n robo-stack-prod --timeout=120s

# Verify pods are healthy
kubectl get pods -n robo-stack-prod -l app=claude-proxy
```

### 3.4 Post-Rollback

1. Verify application health: `curl -s http://<prod-endpoint>/health`
2. Check logs for errors: `kubectl logs -n robo-stack-prod -l app=claude-proxy --tail=50`
3. Update deploy-metadata ConfigMap with rollback info
4. File a post-incident report if the rollback was unplanned
5. Investigate root cause before re-attempting deployment

---

## 4. Alert Response Procedures

### 4.1 HighCPUUsage

**Alert:** CPU usage exceeds 80% for 5+ minutes.

**Investigation:**
```bash
# Identify top consumers
kubectl top pods -n robo-stack-prod --sort-by=cpu
ssh ubuntu@$NODE_HOST "top -bn1 | head -20"

# Check for stuck processes or hot loops
kubectl logs -n robo-stack-prod <pod-name> --tail=100

# Check for horizontal scaling opportunity
kubectl get hpa -n robo-stack-prod
```

**Resolution:**
- If a single pod: Restart it (`kubectl delete pod <name> -n robo-stack-prod`)
- If cluster-wide: Check for DDoS, noisy neighbor, or resource leak
- Scale up if legitimate traffic: `kubectl scale deployment claude-proxy --replicas=3 -n robo-stack-prod`
- Long term: Adjust resource limits or add HPA

### 4.2 HighMemoryUsage

**Alert:** Memory usage exceeds 85% for 5+ minutes.

**Investigation:**
```bash
kubectl top pods -n robo-stack-prod --sort-by=memory
ssh ubuntu@$NODE_HOST "free -h"
kubectl describe node | grep -A5 "Allocated resources"
```

**Resolution:**
- If a single pod with memory leak: Restart it and file a bug
- If cluster-wide: Check for resource quota violations
- Emergency: Evict low-priority pods, increase node memory

### 4.3 PodCrashLooping

**Alert:** Pod has restarted more than 3 times in 10 minutes.

**Investigation:**
```bash
# Get pod status and restart count
kubectl get pods -n robo-stack-prod -o wide

# Check pod events
kubectl describe pod <pod-name> -n robo-stack-prod

# Check current logs
kubectl logs -n robo-stack-prod <pod-name> --tail=100

# Check previous container logs (before crash)
kubectl logs -n robo-stack-prod <pod-name> --previous --tail=100
```

**Resolution:**
- OOMKilled: Increase memory limits in the deployment spec
- CrashLoopBackOff with config error: Fix ConfigMap/Secret and redeploy
- Application bug: Rollback to last known good version (see Section 3)

### 4.4 PrometheusTargetDown

**Alert:** A Prometheus scrape target has been unreachable for 5+ minutes.

**Investigation:**
```bash
# Check which target is down
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health!="up")'

# Check if the pod exists
kubectl get pods -n robo-stack-prod -l <target-label>

# Check service endpoints
kubectl get endpoints -n robo-stack-prod
```

**Resolution:**
- Pod not running: Check deployment status, describe pod for events
- Service misconfigured: Verify Service selector matches pod labels
- Network policy blocking: Check NetworkPolicy allows Prometheus scrape

### 4.5 DiskSpaceLow

**Alert:** Disk usage exceeds 85%.

**Investigation:**
```bash
ssh ubuntu@$NODE_HOST "df -h"
ssh ubuntu@$NODE_HOST "du -sh /var/log/* | sort -rh | head -10"
ssh ubuntu@$NODE_HOST "sudo crictl images | sort -k3 -rh | head -10"
kubectl get pvc -A
```

**Resolution:**
- Clean old container images: `ssh ubuntu@$NODE_HOST "sudo crictl rmi --prune"`
- Rotate logs: `ssh ubuntu@$NODE_HOST "sudo journalctl --vacuum-size=500M"`
- Clean old Prometheus data if TSDB is large: Adjust `--storage.tsdb.retention.size`
- Expand PVC if using dynamic provisioning (see Section 6.2)

### 4.6 CertificateExpiringSoon

**Alert:** TLS certificate expires within 14 days.

**Investigation:**
```bash
# Check certificate expiry
echo | openssl s_client -connect <endpoint>:443 2>/dev/null | openssl x509 -noout -dates

# Check K8s TLS secrets
kubectl get secrets -n robo-stack-prod -o json | jq '.items[] | select(.type=="kubernetes.io/tls") | .metadata.name'
```

**Resolution:**
- If using cert-manager: Check Certificate and CertificateRequest resources
- Manual renewal: Generate new cert, update K8s secret, restart affected pods
- Verify renewal: Re-check expiry after update

### 4.7 HighErrorRate

**Alert:** HTTP 5xx error rate exceeds 5% for 5+ minutes.

**Investigation:**
```bash
# Check application logs for errors
kubectl logs -n robo-stack-prod -l app=claude-proxy --since=10m | grep -i "error\|500\|503"

# Check metrics
curl -s http://localhost:9090/api/v1/query?query=rate(http_requests_total{status=~"5.."}[5m])

# Check upstream dependencies
curl -s http://localhost:8080/health
```

**Resolution:**
- If upstream API (Claude) is down: Check Anthropic status page, enable circuit breaker
- If application error: Check logs, rollback if recent deploy
- If rate limiting hit: Check rate limit configuration

---

## 5. Secret Rotation Procedures

### 5.1 Claude API Key Rotation

**Frequency:** Every 90 days or immediately if compromised.

```bash
# 1. Generate new API key in Anthropic console
#    https://console.anthropic.com/settings/keys

# 2. Update K8s secret
kubectl create secret generic claude-api-key \
  -n robo-stack-prod \
  --from-literal=ANTHROPIC_API_KEY='sk-ant-new-key-here' \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Restart pods to pick up new secret
kubectl rollout restart deployment/claude-proxy -n robo-stack-prod

# 4. Verify health
kubectl rollout status deployment/claude-proxy -n robo-stack-prod --timeout=120s
curl -s http://localhost:8080/health

# 5. Revoke the old key in Anthropic console

# 6. Update GitHub Actions secret if used in CI
gh secret set ANTHROPIC_API_KEY --body 'sk-ant-new-key-here' --repo LittleYeti-Dev/robo-stack
```

### 5.2 Kubeconfig Rotation

**Frequency:** Every 90 days or when team membership changes.

```bash
# 1. On the K3s node, regenerate kubeconfig
ssh ubuntu@$NODE_HOST "sudo k3s kubectl config view --raw"

# 2. Copy new kubeconfig locally
scp ubuntu@$NODE_HOST:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# 3. Update the server address in kubeconfig
sed -i '' "s|https://127.0.0.1:6443|https://${NODE_HOST}:6443|g" ~/.kube/config

# 4. Verify access
kubectl get nodes

# 5. Update GitHub Actions secret
gh secret set KUBECONFIG_B64 \
  --body "$(base64 < ~/.kube/config)" \
  --repo LittleYeti-Dev/robo-stack

# 6. Invalidate previous kubeconfig tokens if K3s supports it
```

### 5.3 GHCR (GitHub Container Registry) Token Rotation

**Frequency:** Every 90 days or when revoked.

```bash
# 1. Generate new Personal Access Token (PAT) in GitHub
#    Settings > Developer Settings > Personal Access Tokens > Fine-grained
#    Permissions: read:packages, write:packages

# 2. Update K8s image pull secret
kubectl create secret docker-registry ghcr-pull-secret \
  -n robo-stack-prod \
  --docker-server=ghcr.io \
  --docker-username=LittleYeti-Dev \
  --docker-password='ghp_NEW_TOKEN_HERE' \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Also update for staging and dev namespaces
for NS in robo-stack robo-stack-staging; do
  kubectl create secret docker-registry ghcr-pull-secret \
    -n "$NS" \
    --docker-server=ghcr.io \
    --docker-username=LittleYeti-Dev \
    --docker-password='ghp_NEW_TOKEN_HERE' \
    --dry-run=client -o yaml | kubectl apply -f -
done

# 4. Update GitHub Actions secret
gh secret set GHCR_PAT --body 'ghp_NEW_TOKEN_HERE' --repo LittleYeti-Dev/robo-stack

# 5. Verify image pull works
kubectl run test-pull --image=ghcr.io/littleyeti-dev/robo-stack:latest \
  --restart=Never -n robo-stack --rm -it -- echo "Pull OK"

# 6. Revoke old PAT in GitHub settings
```

### 5.4 Grafana Admin Password Rotation

```bash
# 1. Generate new password
NEW_PASS=$(openssl rand -base64 24)

# 2. Update K8s secret
kubectl create secret generic grafana-admin \
  -n robo-stack-prod \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$NEW_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Restart Grafana
kubectl rollout restart deployment/grafana -n robo-stack-prod

# 4. Record new password in secure password manager (NOT in git)
echo "New Grafana admin password: $NEW_PASS"
echo "Store this in your password manager immediately."
```

---

## 6. Emergency Procedures

### 6.1 Node Down

**Symptoms:** Node unreachable via SSH, kubectl reports NotReady, pods evicted.

**Step 1 -- Verify the problem:**
```bash
# Try ping
ping -c 3 $NODE_HOST

# Try SSH
ssh -o ConnectTimeout=5 ubuntu@$NODE_HOST "echo ok"

# Check from cloud console
# AWS: aws ec2 describe-instance-status --instance-ids <id>
```

**Step 2 -- If SSH works but K3s is down:**
```bash
ssh ubuntu@$NODE_HOST << 'EOF'
  # Check K3s status
  sudo systemctl status k3s

  # Check system logs
  sudo journalctl -u k3s --since "10 minutes ago" --no-pager | tail -50

  # Restart K3s
  sudo systemctl restart k3s

  # Wait for it to come up
  sleep 15

  # Verify
  sudo k3s kubectl get nodes
EOF
```

**Step 3 -- If SSH does not work:**
```bash
# AWS Console: Reboot instance
# aws ec2 reboot-instances --instance-ids <id>

# Wait 2-3 minutes then retry SSH
sleep 180
ssh ubuntu@$NODE_HOST "uptime"

# If still unreachable: Stop and Start (gets new underlying host)
# aws ec2 stop-instances --instance-ids <id>
# aws ec2 start-instances --instance-ids <id>
# WARNING: Public IP may change if not using Elastic IP
```

**Step 4 -- After recovery:**
```bash
# Verify all nodes
kubectl get nodes

# Check pod status
kubectl get pods -A | grep -v Running

# Re-run health checks
./scripts/prod-readiness-check.sh
```

### 6.2 Disk Full

**Symptoms:** Pods failing to start, write errors in logs, node pressure taints.

**Step 1 -- Identify what is consuming space:**
```bash
ssh ubuntu@$NODE_HOST << 'EOF'
  df -h
  echo "--- Largest directories ---"
  sudo du -sh /var/lib/rancher/k3s/* 2>/dev/null | sort -rh | head -10
  sudo du -sh /var/log/* 2>/dev/null | sort -rh | head -10
  sudo du -sh /var/lib/containerd/* 2>/dev/null | sort -rh | head -10
EOF
```

**Step 2 -- Clean up:**
```bash
ssh ubuntu@$NODE_HOST << 'EOF'
  # Clean old container images
  sudo crictl rmi --prune

  # Rotate journal logs
  sudo journalctl --vacuum-size=200M

  # Clean old K3s data (pods that are gone)
  sudo k3s crictl rmi --prune

  # Clean /tmp
  sudo find /tmp -type f -atime +7 -delete

  # Verify space recovered
  df -h
EOF
```

**Step 3 -- Expand PVC (if Prometheus/Loki data is the problem):**
```bash
# Check PVC usage
kubectl get pvc -n robo-stack-prod

# If using expandable storage class:
kubectl patch pvc prometheus-data -n robo-stack-prod \
  -p '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}'

# Alternative: Reduce Prometheus retention
kubectl set env deployment/prometheus -n robo-stack-prod \
  -- --storage.tsdb.retention.size=5GB
```

**Step 4 -- Verify recovery:**
```bash
kubectl describe node | grep -A3 "Conditions"
# DiskPressure should be False
kubectl get pods -n robo-stack-prod
```

### 6.3 API Key Compromised

**Symptoms:** Unexpected API usage, billing spikes, unauthorized requests in logs.

**IMMEDIATE ACTIONS (do these within 5 minutes):**

```bash
# 1. REVOKE the compromised key immediately
# Go to the provider's console and revoke/delete the key.
# For Claude API: https://console.anthropic.com/settings/keys
# For GitHub PAT: GitHub Settings > Developer Settings > Personal Access Tokens

# 2. Remove the key from any running workloads
kubectl delete secret claude-api-key -n robo-stack-prod

# 3. Scale down the affected deployment to stop all traffic
kubectl scale deployment claude-proxy --replicas=0 -n robo-stack-prod
```

**RECOVERY (within 30 minutes):**

```bash
# 4. Generate a NEW key from the provider console

# 5. Create new K8s secret
kubectl create secret generic claude-api-key \
  -n robo-stack-prod \
  --from-literal=ANTHROPIC_API_KEY='sk-ant-NEW-KEY'

# 6. Scale deployment back up
kubectl scale deployment claude-proxy --replicas=1 -n robo-stack-prod

# 7. Verify
kubectl rollout status deployment/claude-proxy -n robo-stack-prod
curl -s http://localhost:8080/health
```

**POST-INCIDENT (within 24 hours):**

```bash
# 8. Check git history for the compromised key
cd /path/to/robo-stack
git log --all --oneline -p | grep -l 'sk-ant-COMPROMISED' || echo "Not found in git"

# 9. If found in git, use BFG or git-filter-repo to remove
# WARNING: This rewrites history. Coordinate with team.
# bfg --replace-text passwords.txt .

# 10. Run gitleaks to verify no other secrets exposed
gitleaks detect --source . --verbose

# 11. Update all CI/CD secrets
gh secret set ANTHROPIC_API_KEY --body 'sk-ant-NEW-KEY' --repo LittleYeti-Dev/robo-stack

# 12. File a post-incident report
# - What was compromised
# - When it was discovered
# - What actions were taken
# - Root cause analysis
# - Preventive measures
```

### 6.4 Cluster Unresponsive

**Symptoms:** kubectl commands hang or timeout, API server unreachable.

**Step 1 -- Diagnose:**
```bash
# Check if the API server port is reachable
nc -zv $NODE_HOST 6443 -w 5

# Check from the node itself
ssh ubuntu@$NODE_HOST "sudo k3s kubectl get nodes --request-timeout=10s"
```

**Step 2 -- K3s restart:**
```bash
ssh ubuntu@$NODE_HOST << 'EOF'
  # Check K3s process
  sudo systemctl status k3s

  # Check for resource exhaustion
  free -h
  df -h
  uptime

  # Check K3s logs for errors
  sudo journalctl -u k3s --since "5 minutes ago" --no-pager | tail -30

  # Restart K3s
  sudo systemctl restart k3s

  # Wait for API server
  echo "Waiting for API server..."
  for i in $(seq 1 30); do
    if sudo k3s kubectl get nodes --request-timeout=5s &>/dev/null; then
      echo "API server is back"
      break
    fi
    sleep 5
  done
EOF
```

**Step 3 -- Pod recovery:**
```bash
# After K3s is back, check pod status
kubectl get pods -A | grep -v Running

# Delete stuck pods (they will be recreated by their controllers)
kubectl delete pod <stuck-pod> -n robo-stack-prod --grace-period=0 --force

# If pods are stuck in Terminating state
kubectl get pods -A --field-selector=status.phase=Failed -o name | xargs kubectl delete --force --grace-period=0

# Verify all deployments are healthy
kubectl get deployments -n robo-stack-prod
kubectl get deployments -n robo-stack-staging
```

**Step 4 -- Full node reboot (last resort):**
```bash
ssh ubuntu@$NODE_HOST "sudo reboot"

# Wait 3-5 minutes
sleep 300

# Verify
ssh ubuntu@$NODE_HOST "uptime"
kubectl get nodes
kubectl get pods -A | grep -v Running
```

**Step 5 -- Post-recovery:**
```bash
# Run full health check
./scripts/prod-readiness-check.sh

# Verify monitoring is back
curl -s http://localhost:9090/-/healthy
curl -s http://localhost:30090/api/health
curl -s http://localhost:3100/ready

# Check for data gaps in Prometheus/Loki
# (There will be a gap during the outage -- this is expected)
```

---

## Appendix A: Key Endpoints

| Service | URL | Port |
|---------|-----|------|
| Claude Proxy | http://NODE_HOST:8080 | 8080 |
| Prometheus | http://NODE_HOST:9090 | 9090 |
| Grafana | http://NODE_HOST:30090 | 30090 |
| Loki | http://NODE_HOST:3100 | 3100 |
| K8s API | https://NODE_HOST:6443 | 6443 |

## Appendix B: Key File Locations

| File | Purpose |
|------|---------|
| `scripts/prod-readiness-check.sh` | Full production readiness check suite |
| `scripts/rollback.sh` | Automated rollback script |
| `k8s/hardening/prod-pod-security.yaml` | Pod Security Standards + NetworkPolicies |
| `k8s/hardening/grafana-readonly.yaml` | Grafana read-only hardening |
| `k8s/hardening/prometheus-security.yaml` | Prometheus security context + web auth |
| `.github/workflows/deploy-prod.yml` | Production deployment pipeline |
| `docs/prod-readiness-report.html` | HTML readiness report template |

## Appendix C: Contact and Escalation

| Role | Contact | When to Escalate |
|------|---------|------------------|
| Project Lead (Yeti) | Primary contact | Any production incident, security event |
| DevSecOps Engineer | On-call | Infrastructure, pipeline, security issues |
| Platform Architect | As needed | Architecture decisions, K8s design |

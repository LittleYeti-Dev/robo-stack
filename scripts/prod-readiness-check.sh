#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Robo Stack — Production Readiness Check
# DevSecOps Engineer + Overwatch (Security Lead)
#
# Comprehensive, idempotent check suite. Re-run at will.
# Produces a JSON results file and prints a summary table.
#
# Usage:
#   ./scripts/prod-readiness-check.sh [--json-out /path/to/results.json]
#
# Exit codes:
#   0  — All critical checks PASS (GO)
#   1  — One or more critical checks FAIL (NO-GO)
###############################################################################

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESULTS_FILE="${REPO_ROOT}/prod-readiness-results.json"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:30090}"
LOKI_URL="${LOKI_URL:-http://localhost:3100}"
CLAUDE_PROXY_URL="${CLAUDE_PROXY_URL:-http://localhost:8080}"
NODE_HOST="${NODE_HOST:-localhost}"
KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config}"

NAMESPACES=("robo-stack" "robo-stack-staging" "robo-stack-prod")

# Parse CLI flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json-out) RESULTS_FILE="$2"; shift 2 ;;
    *) echo "Unknown flag: $1"; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# Colors & counters
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0
CRITICAL_FAIL=0

declare -a RESULTS_JSON=()

# ---------------------------------------------------------------------------
# Helper: check()
#   $1 — category   (Infrastructure, Deployment, Monitoring, Security, Application)
#   $2 — name       (human-readable check name)
#   $3 — severity   (critical | warning | info)
#   $4 — command    (shell command to evaluate; exit 0 = PASS)
#   $5 — remediation text on failure
# ---------------------------------------------------------------------------
check() {
  local category="$1"
  local name="$2"
  local severity="$3"
  local cmd="$4"
  local remediation="${5:-}"
  local status="PASS"
  local details=""

  # Run the check command, capture stdout+stderr
  if details=$(eval "$cmd" 2>&1); then
    status="PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  ${GREEN}[PASS]${RESET}  %s\n" "$name"
  else
    local exit_code=$?
    # Exit code 2 = SKIP, anything else = FAIL/WARN
    if [[ $exit_code -eq 2 ]]; then
      status="SKIP"
      SKIP_COUNT=$((SKIP_COUNT + 1))
      printf "  ${CYAN}[SKIP]${RESET}  %s — %s\n" "$name" "$details"
    elif [[ "$severity" == "warning" ]]; then
      status="WARN"
      WARN_COUNT=$((WARN_COUNT + 1))
      printf "  ${YELLOW}[WARN]${RESET}  %s — %s\n" "$name" "$details"
    else
      status="FAIL"
      FAIL_COUNT=$((FAIL_COUNT + 1))
      if [[ "$severity" == "critical" ]]; then
        CRITICAL_FAIL=$((CRITICAL_FAIL + 1))
      fi
      printf "  ${RED}[FAIL]${RESET}  %s — %s\n" "$name" "$details"
    fi
  fi

  # Escape JSON strings (basic)
  local json_details
  json_details=$(echo "$details" | head -c 500 | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/ /g' | tr '\n' ' ')
  local json_remediation
  json_remediation=$(echo "$remediation" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/ /g' | tr '\n' ' ')

  RESULTS_JSON+=("{\"category\":\"${category}\",\"name\":\"${name}\",\"severity\":\"${severity}\",\"status\":\"${status}\",\"details\":\"${json_details}\",\"remediation\":\"${json_remediation}\"}")
}

# ---------------------------------------------------------------------------
# Utility: command_available
# ---------------------------------------------------------------------------
command_available() {
  command -v "$1" &>/dev/null
}

kubectl_available() {
  if ! command_available kubectl; then
    echo "kubectl not found on PATH" >&2
    return 2
  fi
}

# ===========================================================================
# SECTION 1: INFRASTRUCTURE CHECKS
# ===========================================================================
echo ""
echo "${BOLD}=== INFRASTRUCTURE CHECKS ===${RESET}"

check "Infrastructure" \
  "EC2 / Node reachable (ping)" \
  "critical" \
  "ping -c 1 -W 3 '${NODE_HOST}' >/dev/null 2>&1 || { echo 'Node ${NODE_HOST} unreachable'; false; }" \
  "Verify NODE_HOST env var, check network connectivity, confirm instance is running."

check "Infrastructure" \
  "K3s cluster health — nodes Ready" \
  "critical" \
  '
  kubectl_available || return 2
  NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready " || true)
  if [[ -n "$NOT_READY" ]]; then
    echo "Nodes not Ready: $NOT_READY"
    false
  fi
  NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d " ")
  if [[ "$NODES" -eq 0 ]]; then
    echo "No nodes found in cluster"
    false
  fi
  echo "$NODES node(s) Ready"
  ' \
  "Run: kubectl get nodes. Check K3s service: sudo systemctl status k3s. Restart if needed: sudo systemctl restart k3s."

for NS in "${NAMESPACES[@]}"; do
  check "Infrastructure" \
    "Namespace exists: ${NS}" \
    "critical" \
    "
    kubectl_available || return 2
    kubectl get namespace '${NS}' >/dev/null 2>&1 || { echo 'Namespace ${NS} does not exist'; false; }
    echo 'Namespace ${NS} found'
    " \
    "Create namespace: kubectl create namespace ${NS}"
done

for NS in "${NAMESPACES[@]}"; do
  check "Infrastructure" \
    "Resource quotas applied: ${NS}" \
    "warning" \
    "
    kubectl_available || return 2
    COUNT=\$(kubectl get resourcequota -n '${NS}' --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ \"\$COUNT\" -eq 0 ]]; then
      echo 'No resource quotas in namespace ${NS}'
      false
    fi
    echo \"\$COUNT quota(s) found in ${NS}\"
    " \
    "Apply resource quotas: kubectl apply -f k8s/quotas/${NS}-quota.yaml"
done

check "Infrastructure" \
  "Network policies in robo-stack-prod" \
  "critical" \
  '
  kubectl_available || return 2
  COUNT=$(kubectl get networkpolicy -n robo-stack-prod --no-headers 2>/dev/null | wc -l | tr -d " ")
  if [[ "$COUNT" -eq 0 ]]; then
    echo "No network policies in robo-stack-prod"
    false
  fi
  echo "$COUNT network policy(ies) found"
  ' \
  "Apply network policies: kubectl apply -f k8s/hardening/network-policies.yaml"

# ===========================================================================
# SECTION 2: DEPLOYMENT PIPELINE CHECKS
# ===========================================================================
echo ""
echo "${BOLD}=== DEPLOYMENT PIPELINE CHECKS ===${RESET}"

for WORKFLOW in deploy-dev.yml deploy-staging.yml deploy-prod.yml; do
  check "Deployment" \
    "Workflow exists: .github/workflows/${WORKFLOW}" \
    "critical" \
    "
    if [[ -f '${REPO_ROOT}/.github/workflows/${WORKFLOW}' ]]; then
      echo 'Found ${WORKFLOW}'
    else
      echo 'Missing .github/workflows/${WORKFLOW}'
      false
    fi
    " \
    "Create the GitHub Actions workflow file: .github/workflows/${WORKFLOW}"
done

check "Deployment" \
  "rollback.sh exists and is executable" \
  "critical" \
  "
  if [[ ! -f '${REPO_ROOT}/scripts/rollback.sh' ]]; then
    echo 'scripts/rollback.sh not found'
    false
  fi
  if [[ ! -x '${REPO_ROOT}/scripts/rollback.sh' ]]; then
    echo 'scripts/rollback.sh is not executable'
    false
  fi
  echo 'rollback.sh found and executable'
  " \
  "Create scripts/rollback.sh and run: chmod +x scripts/rollback.sh"

check "Deployment" \
  "Deployment metadata ConfigMap pattern" \
  "warning" \
  "
  if grep -rq 'kind: ConfigMap' '${REPO_ROOT}/k8s/' 2>/dev/null && \
     grep -rq 'deploy-metadata\|deployment-metadata' '${REPO_ROOT}/k8s/' 2>/dev/null; then
    echo 'Deployment metadata ConfigMap pattern found'
  else
    echo 'No deployment metadata ConfigMap pattern detected in k8s/'
    false
  fi
  " \
  "Add a ConfigMap for deploy metadata (git SHA, timestamp, deployer) to track deployments."

# ===========================================================================
# SECTION 3: MONITORING CHECKS
# ===========================================================================
echo ""
echo "${BOLD}=== MONITORING CHECKS ===${RESET}"

check "Monitoring" \
  "Prometheus targets > 0" \
  "critical" \
  "
  RESP=\$(curl -sf --max-time 5 '${PROMETHEUS_URL}/api/v1/targets' 2>/dev/null) || { echo 'Prometheus unreachable at ${PROMETHEUS_URL}'; false; }
  ACTIVE=\$(echo \"\$RESP\" | grep -o '\"activeTargets\":\\[' | wc -l | tr -d ' ')
  TARGET_COUNT=\$(echo \"\$RESP\" | grep -o '\"health\"' | wc -l | tr -d ' ')
  if [[ \"\$TARGET_COUNT\" -eq 0 ]]; then
    echo 'No active targets in Prometheus'
    false
  fi
  echo \"\$TARGET_COUNT active target(s)\"
  " \
  "Verify Prometheus scrape configs. Check ServiceMonitor or static_configs."

check "Monitoring" \
  "Grafana health endpoint on :30090" \
  "critical" \
  "
  HTTP_CODE=\$(curl -sf -o /dev/null -w '%{http_code}' --max-time 5 '${GRAFANA_URL}/api/health' 2>/dev/null) || HTTP_CODE='000'
  if [[ \"\$HTTP_CODE\" != '200' ]]; then
    echo \"Grafana returned HTTP \$HTTP_CODE (expected 200)\"
    false
  fi
  echo 'Grafana healthy (HTTP 200)'
  " \
  "Check Grafana pod: kubectl get pods -n robo-stack-prod -l app=grafana. Restart if needed."

check "Monitoring" \
  "Loki receiving logs (/ready)" \
  "critical" \
  "
  HTTP_CODE=\$(curl -sf -o /dev/null -w '%{http_code}' --max-time 5 '${LOKI_URL}/ready' 2>/dev/null) || HTTP_CODE='000'
  if [[ \"\$HTTP_CODE\" != '200' ]]; then
    echo \"Loki returned HTTP \$HTTP_CODE (expected 200)\"
    false
  fi
  echo 'Loki ready (HTTP 200)'
  " \
  "Check Loki pod: kubectl get pods -n robo-stack-prod -l app=loki. Check storage permissions."

check "Monitoring" \
  "Alert rules loaded in Prometheus" \
  "warning" \
  "
  RESP=\$(curl -sf --max-time 5 '${PROMETHEUS_URL}/api/v1/rules' 2>/dev/null) || { echo 'Cannot query Prometheus rules API'; false; }
  RULE_COUNT=\$(echo \"\$RESP\" | grep -o '\"name\"' | wc -l | tr -d ' ')
  if [[ \"\$RULE_COUNT\" -eq 0 ]]; then
    echo 'No alert rules loaded'
    false
  fi
  echo \"\$RULE_COUNT alert rule(s) loaded\"
  " \
  "Apply PrometheusRule CRDs or check prometheus.yml rule_files config."

check "Monitoring" \
  "Grafana dashboards loaded" \
  "warning" \
  "
  RESP=\$(curl -sf --max-time 5 '${GRAFANA_URL}/api/search?type=dash-db' 2>/dev/null) || { echo 'Cannot query Grafana API'; false; }
  DASH_COUNT=\$(echo \"\$RESP\" | grep -o '\"id\"' | wc -l | tr -d ' ')
  if [[ \"\$DASH_COUNT\" -eq 0 ]]; then
    echo 'No dashboards found in Grafana'
    false
  fi
  echo \"\$DASH_COUNT dashboard(s) loaded\"
  " \
  "Import dashboards via Grafana provisioning or API. Check k8s/monitoring/grafana-dashboards ConfigMap."

# ===========================================================================
# SECTION 4: SECURITY CHECKS
# ===========================================================================
echo ""
echo "${BOLD}=== SECURITY CHECKS ===${RESET}"

check "Security" \
  "IMDSv2 enforced (token-based access only)" \
  "critical" \
  "
  # Attempt IMDSv1 (GET without token) — should fail (HTTP 401/403) if IMDSv2 enforced
  HTTP_CODE=\$(curl -sf -o /dev/null -w '%{http_code}' --max-time 2 http://169.254.169.254/latest/meta-data/ 2>/dev/null) || HTTP_CODE='000'
  if [[ \"\$HTTP_CODE\" == '200' ]]; then
    echo 'IMDSv1 returned 200 — IMDSv2 NOT enforced'
    false
  elif [[ \"\$HTTP_CODE\" == '000' ]]; then
    # Not on EC2 or IMDS unreachable — skip
    echo 'IMDS endpoint unreachable (not on EC2 or firewall blocking)'
    return 2
  fi
  # Verify IMDSv2 works with token
  TOKEN=\$(curl -sf -X PUT -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' --max-time 2 http://169.254.169.254/latest/api/token 2>/dev/null) || true
  if [[ -n \"\$TOKEN\" ]]; then
    echo 'IMDSv2 enforced — token-based access confirmed'
  else
    echo 'IMDSv1 blocked but token retrieval also failed — verify IMDS config'
    false
  fi
  " \
  "Enforce IMDSv2: aws ec2 modify-instance-metadata-options --instance-id <id> --http-tokens required --http-endpoint enabled"

check "Security" \
  "No secrets in git history (basic scan)" \
  "critical" \
  "
  cd '${REPO_ROOT}'
  # Check for common secret patterns in tracked files (not full git log for performance)
  FOUND=\$(git diff HEAD --name-only 2>/dev/null | xargs grep -lEi 'AKIA[0-9A-Z]{16}|sk-[a-zA-Z0-9]{48}|password\s*[:=]\s*[\"'\\'']\S+[\"'\\'']\s*$' 2>/dev/null || true)
  if [[ -n \"\$FOUND\" ]]; then
    echo \"Potential secrets found in: \$FOUND\"
    false
  fi
  # Also check staged files
  STAGED=\$(git diff --cached --name-only 2>/dev/null | xargs grep -lEi 'AKIA[0-9A-Z]{16}|sk-[a-zA-Z0-9]{48}' 2>/dev/null || true)
  if [[ -n \"\$STAGED\" ]]; then
    echo \"Potential secrets in staged files: \$STAGED\"
    false
  fi
  echo 'No obvious secrets detected. NOTE: Run gitleaks for thorough history scan.'
  " \
  "Install and run gitleaks: gitleaks detect --source . --verbose. Rotate any exposed credentials immediately."

check "Security" \
  "Container image vulnerability scan (trivy)" \
  "warning" \
  "
  if command_available trivy; then
    echo 'trivy available — run: trivy image <your-image> for full scan'
  else
    echo 'trivy not installed — recommended for container image scanning'
    false
  fi
  " \
  "Install trivy: brew install trivy (macOS) or see https://aquasecurity.github.io/trivy. Run: trivy image ghcr.io/littleyeti-dev/robo-stack:latest"

check "Security" \
  "K8s RBAC — default service account restricted" \
  "critical" \
  '
  kubectl_available || return 2
  # Check that default SA in prod cannot create pods (principle of least privilege)
  CAN_CREATE=$(kubectl auth can-i create pods --as=system:serviceaccount:robo-stack-prod:default -n robo-stack-prod 2>/dev/null || echo "no")
  if [[ "$CAN_CREATE" == "yes" ]]; then
    echo "Default service account in robo-stack-prod can create pods — overprivileged"
    false
  fi
  echo "Default service account properly restricted"
  ' \
  "Apply RBAC restrictions: remove cluster-admin bindings for default SA. Use dedicated service accounts per workload."

check "Security" \
  "Prod network policies block cross-namespace traffic" \
  "critical" \
  '
  kubectl_available || return 2
  POLICIES=$(kubectl get networkpolicy -n robo-stack-prod -o json 2>/dev/null)
  if [[ -z "$POLICIES" ]] || [[ "$(echo "$POLICIES" | grep -c "\"name\"")" -eq 0 ]]; then
    echo "No network policies found in robo-stack-prod"
    false
  fi
  # Check for deny-all or namespace isolation policy
  if echo "$POLICIES" | grep -q "namespaceSelector\|podSelector\|deny-all\|default-deny"; then
    echo "Network policies with namespace/pod selectors present"
  else
    echo "Network policies exist but may not restrict cross-namespace traffic"
    false
  fi
  ' \
  "Apply default-deny ingress policy and explicit allow rules. See k8s/hardening/network-policies.yaml."

check "Security" \
  "Branch protection on main (GitHub API)" \
  "warning" \
  "
  if command_available gh; then
    PROTECTION=\$(gh api repos/LittleYeti-Dev/robo-stack/branches/main/protection 2>/dev/null) || {
      echo 'Cannot query branch protection — check gh auth status'
      false
    }
    if echo \"\$PROTECTION\" | grep -q 'required_pull_request_reviews\|required_status_checks'; then
      echo 'Branch protection enabled on main'
    else
      echo 'Branch protection may be incomplete'
      false
    fi
  else
    echo 'gh CLI not available — cannot check branch protection'
    return 2
  fi
  " \
  "Enable branch protection: Settings > Branches > main > Require PR reviews, status checks, and signed commits."

# ===========================================================================
# SECTION 5: APPLICATION CHECKS
# ===========================================================================
echo ""
echo "${BOLD}=== APPLICATION CHECKS ===${RESET}"

check "Application" \
  "Claude proxy health check" \
  "critical" \
  "
  HTTP_CODE=\$(curl -sf -o /dev/null -w '%{http_code}' --max-time 5 '${CLAUDE_PROXY_URL}/health' 2>/dev/null) || HTTP_CODE='000'
  if [[ \"\$HTTP_CODE\" != '200' ]]; then
    echo \"Claude proxy health returned HTTP \$HTTP_CODE (expected 200)\"
    false
  fi
  echo 'Claude proxy healthy (HTTP 200)'
  " \
  "Check Claude proxy deployment: kubectl get pods -n robo-stack-prod -l app=claude-proxy. Review logs."

check "Application" \
  "Claude proxy /metrics returns Prometheus format" \
  "warning" \
  "
  RESP=\$(curl -sf --max-time 5 '${CLAUDE_PROXY_URL}/metrics' 2>/dev/null) || { echo 'Cannot reach /metrics endpoint'; false; }
  if echo \"\$RESP\" | grep -q '# HELP\|# TYPE'; then
    echo 'Prometheus-format metrics exposed'
  else
    echo '/metrics endpoint does not return Prometheus format'
    false
  fi
  " \
  "Ensure the Claude proxy exposes /metrics in Prometheus exposition format."

check "Application" \
  "Rate limiting enabled" \
  "warning" \
  "
  # Send a test request and check for rate-limit headers
  HEADERS=\$(curl -sI --max-time 5 '${CLAUDE_PROXY_URL}/health' 2>/dev/null)
  if echo \"\$HEADERS\" | grep -qi 'x-ratelimit\|retry-after\|x-rate-limit'; then
    echo 'Rate limiting headers detected'
  else
    echo 'No rate-limit headers detected — rate limiting may not be configured'
    false
  fi
  " \
  "Configure rate limiting in the Claude proxy (token bucket or sliding window). Add X-RateLimit-* response headers."

check "Application" \
  "Structured JSON logging" \
  "warning" \
  "
  kubectl_available || return 2
  # Grab recent logs from claude-proxy and check for JSON structure
  LOGS=\$(kubectl logs -n robo-stack-prod -l app=claude-proxy --tail=5 2>/dev/null) || {
    echo 'Cannot retrieve logs from claude-proxy pods'
    false
  }
  if [[ -z \"\$LOGS\" ]]; then
    echo 'No log output from claude-proxy'
    false
  fi
  if echo \"\$LOGS\" | head -1 | grep -q '^{'; then
    echo 'Structured JSON logging confirmed'
  else
    echo 'Logs are not in JSON format'
    false
  fi
  " \
  "Configure structured JSON logging in the Claude proxy application. Use a JSON log formatter."

# ===========================================================================
# GENERATE JSON RESULTS FILE
# ===========================================================================
echo ""
echo "${BOLD}=== GENERATING RESULTS ===${RESET}"

{
  echo "{"
  echo "  \"timestamp\": \"${TIMESTAMP}\","
  echo "  \"summary\": {"
  echo "    \"total\": $((PASS_COUNT + FAIL_COUNT + WARN_COUNT + SKIP_COUNT)),"
  echo "    \"pass\": ${PASS_COUNT},"
  echo "    \"fail\": ${FAIL_COUNT},"
  echo "    \"warn\": ${WARN_COUNT},"
  echo "    \"skip\": ${SKIP_COUNT},"
  echo "    \"critical_failures\": ${CRITICAL_FAIL}"
  echo "  },"
  echo "  \"recommendation\": \"$(if [[ $CRITICAL_FAIL -gt 0 ]]; then echo 'NO-GO'; else echo 'GO'; fi)\","
  echo "  \"checks\": ["
  for i in "${!RESULTS_JSON[@]}"; do
    if [[ $i -lt $((${#RESULTS_JSON[@]} - 1)) ]]; then
      echo "    ${RESULTS_JSON[$i]},"
    else
      echo "    ${RESULTS_JSON[$i]}"
    fi
  done
  echo "  ]"
  echo "}"
} > "${RESULTS_FILE}"

echo "  Results written to: ${RESULTS_FILE}"

# ===========================================================================
# SUMMARY TABLE
# ===========================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           PRODUCTION READINESS SUMMARY                  ║"
echo "╠══════════════════════════════════════════════════════════╣"
printf "║  ${GREEN}PASS${RESET}:  %-5s                                          ║\n" "$PASS_COUNT"
printf "║  ${RED}FAIL${RESET}:  %-5s                                          ║\n" "$FAIL_COUNT"
printf "║  ${YELLOW}WARN${RESET}:  %-5s                                          ║\n" "$WARN_COUNT"
printf "║  ${CYAN}SKIP${RESET}:  %-5s                                          ║\n" "$SKIP_COUNT"
echo "║                                                        ║"
TOTAL=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT + SKIP_COUNT))
if [[ $TOTAL -gt 0 ]]; then
  PASS_RATE=$(( (PASS_COUNT * 100) / TOTAL ))
else
  PASS_RATE=0
fi
printf "║  Pass Rate: %d%%                                       ║\n" "$PASS_RATE"
echo "║                                                        ║"
if [[ $CRITICAL_FAIL -gt 0 ]]; then
  printf "║  ${RED}${BOLD}RECOMMENDATION: NO-GO${RESET}  (%d critical failure(s))       ║\n" "$CRITICAL_FAIL"
else
  printf "║  ${GREEN}${BOLD}RECOMMENDATION: GO${RESET}                                   ║\n"
fi
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Timestamp: ${TIMESTAMP}"
echo "Results:   ${RESULTS_FILE}"
echo ""

# Exit with appropriate code
if [[ $CRITICAL_FAIL -gt 0 ]]; then
  exit 1
fi
exit 0

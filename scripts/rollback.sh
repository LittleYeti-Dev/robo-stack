#!/usr/bin/env bash
###############################################################################
# rollback.sh — Robo Stack Deployment Rollback
#
# Usage:
#   ./scripts/rollback.sh <namespace> <deployment-name> [revision]
#
# Arguments:
#   namespace        Kubernetes namespace (e.g., robo-stack, robo-stack-staging)
#   deployment-name  Name of the deployment to rollback (e.g., claude-proxy)
#   revision         (Optional) Specific revision number to rollback to
#
# Exit codes:
#   0  Rollback completed successfully
#   1  Rollback failed
###############################################################################
set -euo pipefail

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------
if [ $# -lt 2 ]; then
  echo "Usage: $0 <namespace> <deployment-name> [revision]"
  echo ""
  echo "Arguments:"
  echo "  namespace        Kubernetes namespace"
  echo "  deployment-name  Name of the deployment to rollback"
  echo "  revision         (Optional) Specific revision to rollback to"
  echo ""
  echo "Examples:"
  echo "  $0 robo-stack claude-proxy"
  echo "  $0 robo-stack-staging claude-proxy 3"
  exit 1
fi

NAMESPACE="$1"
DEPLOYMENT="$2"
REVISION="${3:-}"

# ---------------------------------------------------------------------------
# Verify kubectl is available
# ---------------------------------------------------------------------------
if ! command -v kubectl &>/dev/null; then
  echo "ERROR: kubectl is not installed or not in PATH"
  exit 1
fi

# ---------------------------------------------------------------------------
# Verify the namespace exists
# ---------------------------------------------------------------------------
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  echo "ERROR: Namespace '$NAMESPACE' does not exist"
  exit 1
fi

# ---------------------------------------------------------------------------
# Verify the deployment exists
# ---------------------------------------------------------------------------
if ! kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" &>/dev/null; then
  echo "ERROR: Deployment '$DEPLOYMENT' not found in namespace '$NAMESPACE'"
  exit 1
fi

# ---------------------------------------------------------------------------
# Show current deployment info
# ---------------------------------------------------------------------------
echo "============================================================"
echo "  Robo Stack — Deployment Rollback"
echo "============================================================"
echo ""
echo "Namespace:   $NAMESPACE"
echo "Deployment:  $DEPLOYMENT"
echo ""

CURRENT_IMAGE=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].image}')
CURRENT_REPLICAS=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.status.readyReplicas}')
DESIRED_REPLICAS=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.replicas}')

echo "Current image:     $CURRENT_IMAGE"
echo "Current replicas:  ${CURRENT_REPLICAS:-0}/${DESIRED_REPLICAS}"
echo ""

# Show rollout history
echo "--- Rollout History ---"
kubectl rollout history deployment/"$DEPLOYMENT" -n "$NAMESPACE"
echo ""

# ---------------------------------------------------------------------------
# Execute rollback
# ---------------------------------------------------------------------------
if [ -n "$REVISION" ]; then
  if ! [[ "$REVISION" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Revision must be a positive integer, got '$REVISION'"
    exit 1
  fi
  echo "Rolling back to revision $REVISION..."
  if ! kubectl rollout undo deployment/"$DEPLOYMENT" -n "$NAMESPACE" --to-revision="$REVISION"; then
    echo "ERROR: Rollback to revision $REVISION failed"
    exit 1
  fi
else
  echo "Rolling back to previous revision..."
  if ! kubectl rollout undo deployment/"$DEPLOYMENT" -n "$NAMESPACE"; then
    echo "ERROR: Rollback failed"
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Wait for rollout to complete
# ---------------------------------------------------------------------------
echo ""
echo "Waiting for rollout to complete..."
if ! kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=180s; then
  echo "ERROR: Rollout did not complete within 180 seconds"
  exit 1
fi

# ---------------------------------------------------------------------------
# Report results
# ---------------------------------------------------------------------------
NEW_IMAGE=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].image}')
NEW_REPLICAS=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.status.readyReplicas}')

echo ""
echo "============================================================"
echo "  Rollback Complete"
echo "============================================================"
echo ""
echo "Previous image:  $CURRENT_IMAGE"
echo "Current image:   $NEW_IMAGE"
echo "Ready replicas:  ${NEW_REPLICAS:-0}/${DESIRED_REPLICAS}"
echo ""

if [ "$CURRENT_IMAGE" = "$NEW_IMAGE" ]; then
  echo "WARNING: Image did not change — the rollback target may use the same image."
fi

echo "Rollback successful."
exit 0

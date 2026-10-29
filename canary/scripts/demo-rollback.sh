#!/usr/bin/env bash
# Ships a deliberately broken release and measures how long it takes
# Argo Rollouts to detect it via Prometheus and roll back automatically.
#
# Usage: scripts/demo-rollback.sh [release] [timeout-seconds]
set -euo pipefail

RELEASE="${1:-canary-app}"
TIMEOUT="${2:-300}"
CHART="$(dirname "$0")/../charts/canary-app"

phase() { kubectl get rollout "$RELEASE" -o jsonpath='{.status.phase}'; }

if [[ "$(phase)" != "Healthy" ]]; then
  echo "Rollout $RELEASE is $(phase), expected Healthy. Run 'make deploy' first." >&2
  exit 1
fi

stable_before=$(kubectl get rollout "$RELEASE" -o jsonpath='{.status.stableRS}')
echo "Stable ReplicaSet hash: $stable_before"
echo "Shipping broken release (30% HTTP 500s)..."

start=$(date +%s)
helm upgrade "$RELEASE" "$CHART" --server-side=false --reuse-values \
  --set app.version="bad-$start" --set fault.errorRate=0.3 >/dev/null

while true; do
  elapsed=$(( $(date +%s) - start ))
  p=$(phase)
  aborted=$(kubectl get rollout "$RELEASE" -o jsonpath='{.status.abort}')
  printf '\r[%3ss] phase=%-12s' "$elapsed" "$p"

  if [[ "$aborted" == "true" ]]; then
    echo
    stable_after=$(kubectl get rollout "$RELEASE" -o jsonpath='{.status.stableRS}')
    canary_ready=$(kubectl get rollout "$RELEASE" -o jsonpath='{.status.canary.weights.canary.weight}')
    echo "Rollback triggered after ${elapsed}s"
    echo "Stable ReplicaSet still: $stable_after (unchanged: $([[ $stable_after == "$stable_before" ]] && echo yes || echo NO))"
    echo "Canary weight now: ${canary_ready:-0}%"
    kubectl get analysisrun --sort-by=.metadata.creationTimestamp | tail -n 1
    [[ "$stable_after" == "$stable_before" ]]
    exit $?
  fi

  if [[ "$p" == "Healthy" && "$elapsed" -gt 20 ]]; then
    echo; echo "FAIL: broken release was promoted" >&2; exit 1
  fi
  if (( elapsed > TIMEOUT )); then
    echo; echo "FAIL: no rollback within ${TIMEOUT}s" >&2; exit 1
  fi
  sleep 2
done

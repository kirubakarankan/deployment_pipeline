#!/usr/bin/env bash
# Ships a deliberately broken release and measures how long it takes the
# pre-promotion analysis to catch it. The bad version must never reach the
# active Service, so users keep getting the old one the whole time.
#
# Usage: scripts/demo-rollback.sh [release] [timeout-seconds] [error|latency]
set -euo pipefail

RELEASE="${1:-bluegreen-app}"
TIMEOUT="${2:-300}"
SCENARIO="${3:-error}"
CHART="$(dirname "$0")/../charts/bluegreen-app"

case "$SCENARIO" in
  error)   FAULT=(--set fault.errorRate=0.3);  DESC="30% HTTP 500s" ;;
  latency) FAULT=(--set fault.latencyMs=800);  DESC="800ms added latency" ;;
  *) echo "Unknown scenario '$SCENARIO', use error or latency." >&2; exit 1 ;;
esac

phase() { kubectl get rollout "$RELEASE" -o jsonpath='{.status.phase}'; }
# What the active Service really selects, which is what users hit.
active_hash() { kubectl get svc "$RELEASE-active" -o jsonpath='{.spec.selector.rollouts-pod-template-hash}'; }

if [[ "$(phase)" != "Healthy" ]]; then
  echo "Rollout $RELEASE is $(phase), expected Healthy. Run 'make deploy' or 'make release-good' first." >&2
  exit 1
fi

active_before=$(active_hash)
echo "Active ReplicaSet hash: $active_before"
echo "Shipping broken release ($DESC)..."

start=$(date +%s)
helm upgrade "$RELEASE" "$CHART" --server-side=false --reuse-values \
  --set app.version="bad-$start" "${FAULT[@]}" >/dev/null

while true; do
  elapsed=$(( $(date +%s) - start ))
  p=$(phase)
  aborted=$(kubectl get rollout "$RELEASE" -o jsonpath='{.status.abort}')
  printf '\r[%3ss] phase=%-12s' "$elapsed" "$p"

  if [[ "$aborted" == "true" ]]; then
    echo
    active_after=$(active_hash)
    echo "Release blocked after ${elapsed}s"
    echo "Active ReplicaSet still: $active_after (unchanged: $([[ $active_after == "$active_before" ]] && echo yes || echo NO))"
    kubectl get analysisrun --sort-by=.metadata.creationTimestamp | tail -n 1
    [[ "$active_after" == "$active_before" ]]
    exit $?
  fi

  if [[ "$(active_hash)" != "$active_before" ]]; then
    echo; echo "FAIL: broken release was promoted" >&2; exit 1
  fi
  if (( elapsed > TIMEOUT )); then
    echo; echo "FAIL: not blocked within ${TIMEOUT}s" >&2; exit 1
  fi
  sleep 2
done

#!/usr/bin/env bash
# Ships a deliberately broken release and measures how long Argo Rollouts
# takes to stop it. "post" breaks only after the switch, so the active
# Service has to flip back.
#
# Usage: scripts/demo-rollback.sh [release] [timeout-seconds] [error|latency|post]
set -euo pipefail

RELEASE="${1:-bluegreen-app}"
TIMEOUT="${2:-300}"
SCENARIO="${3:-error}"
CHART="$(dirname "$0")/../charts/bluegreen-app"

case "$SCENARIO" in
  error)   FAULT=(--set fault.errorRate=0.3);  DESC="30% HTTP 500s" ;;
  latency) FAULT=(--set fault.latencyMs=800);  DESC="800ms added latency" ;;
  # Must outlast the pre-promotion check (~90s), so the bad pods pass it; 50%
  # errors because the 1m rate window needs two failing samples before the end.
  post)    FAULT=(--set fault.errorRate=0.5 --set fault.afterSeconds=110); DESC="50% HTTP 500s starting 110s after boot" ;;
  *) echo "Unknown scenario '$SCENARIO', use error, latency or post." >&2; exit 1 ;;
esac

phase() { kubectl get rollout "$RELEASE" -o jsonpath='{.status.phase}'; }
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

promoted_at=""
while true; do
  now=$(date +%s)
  elapsed=$(( now - start ))
  p=$(phase)
  aborted=$(kubectl get rollout "$RELEASE" -o jsonpath='{.status.abort}')
  active_now=$(active_hash)
  printf '\r[%3ss] phase=%-12s' "$elapsed" "$p"

  if [[ "$SCENARIO" == "post" ]]; then
    if [[ -z "$promoted_at" && "$active_now" != "$active_before" ]]; then
      promoted_at=$now
    elif [[ -n "$promoted_at" && "$active_now" == "$active_before" ]]; then
      echo
      echo "Promoted after $(( promoted_at - start ))s, rolled back $(( now - promoted_at ))s later"
      echo "Active ReplicaSet back on: $active_now"
      kubectl get analysisrun --sort-by=.metadata.creationTimestamp | tail -n 1
      exit 0
    elif [[ -z "$promoted_at" && "$aborted" == "true" ]]; then
      echo; echo "FAIL: stopped before promotion, the fault started too early" >&2; exit 1
    fi
  elif [[ "$aborted" == "true" ]]; then
    echo
    active_after=$(active_hash)
    echo "Release blocked after ${elapsed}s"
    echo "Active ReplicaSet still: $active_after (unchanged: $([[ $active_after == "$active_before" ]] && echo yes || echo NO))"
    kubectl get analysisrun --sort-by=.metadata.creationTimestamp | tail -n 1
    [[ "$active_after" == "$active_before" ]]
    exit $?
  fi

  if [[ "$SCENARIO" != "post" && "$active_now" != "$active_before" ]]; then
    echo; echo "FAIL: broken release was promoted" >&2; exit 1
  fi
  if (( elapsed > TIMEOUT )); then
    echo; echo "FAIL: not stopped within ${TIMEOUT}s" >&2; exit 1
  fi
  sleep 2
done

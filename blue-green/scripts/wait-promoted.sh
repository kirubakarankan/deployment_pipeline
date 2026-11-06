#!/usr/bin/env bash
# Waits until the current pod template is the stable one and the rollout is
# Healthy, i.e. the release finished its pre and post promotion checks.
#
# Usage: scripts/wait-promoted.sh [release]
set -euo pipefail

RELEASE="${1:-bluegreen-app}"

for i in $(seq 1 96); do
  stable=$(kubectl get rollout "$RELEASE" -o jsonpath='{.status.stableRS}')
  current=$(kubectl get rollout "$RELEASE" -o jsonpath='{.status.currentPodHash}')
  phase=$(kubectl get rollout "$RELEASE" -o jsonpath='{.status.phase}')
  echo "[$((i * 5))s] phase=$phase stable=$stable current=$current"
  # A rollout aborted by an earlier bad release still reads Degraded for a moment.
  [[ "$i" -gt 3 && "$phase" == "Degraded" ]] && { echo "release was rolled back" >&2; exit 1; }
  [[ "$i" -gt 2 && "$phase" == "Healthy" && "$stable" == "$current" ]] && exit 0
  sleep 5
done
echo "timed out waiting for promotion" >&2; exit 1

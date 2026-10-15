#!/bin/bash
set -euo pipefail

RESTART_THRESHOLD=${1:-10}

echo "Checking pods with > $RESTART_THRESHOLD restarts..." >&2

oc get pods -A -o json | jq -r --arg threshold "$RESTART_THRESHOLD" '
  .items[] |
  select(.status.containerStatuses != null) |
  select(.status.containerStatuses[].restartCount > ($threshold | tonumber)) |
  "\(.metadata.namespace)|\(.metadata.name)|\(.status.containerStatuses[].restartCount)"
'

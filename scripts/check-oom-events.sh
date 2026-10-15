#!/bin/bash
set -euo pipefail

LOOKBACK_DAYS=${1:-6}

echo "Checking OOMKilled events in last $LOOKBACK_DAYS days..." >&2

oc get events -A --field-selector reason=OOMKilling \
  --sort-by='.lastTimestamp' -o json | jq -r '
  .items[] |
  select(.lastTimestamp != null) |
  "\(.lastTimestamp)|\(.involvedObject.namespace)|\(.involvedObject.name)"
' | while read line; do
  IFS='|' read -r timestamp ns pod <<< "$line"
  age_days=$(( ($(date +%s) - $(date -d "$timestamp" +%s)) / 86400 ))

  if [ $age_days -le $LOOKBACK_DAYS ]; then
    echo "$ns|$pod|$age_days|$timestamp"
  fi
done

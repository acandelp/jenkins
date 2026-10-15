#!/bin/bash
set -euo pipefail

LOOKBACK_DAYS=${1:-6}

echo "Checking degraded operators in last $LOOKBACK_DAYS days..." >&2

oc get clusteroperators -o json | jq -r '
  .items[] |
  select(.status.conditions[] |
    select(.type == "Degraded" and .status == "True" and .lastTransitionTime != null)
  ) |
  "\(.metadata.name)|\(.status.conditions[] | select(.type == \"Degraded\") | .lastTransitionTime)|\(.status.conditions[] | select(.type == \"Degraded\") | .message)"
' | while read line; do
  IFS='|' read -r operator timestamp message <<< "$line"
  age_days=$(( ($(date +%s) - $(date -d "$timestamp" +%s)) / 86400 ))

  if [ $age_days -le $LOOKBACK_DAYS ]; then
    echo "$operator|$age_days|$message"
  fi
done

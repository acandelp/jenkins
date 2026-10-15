#!/bin/bash
set -euo pipefail

LOOKBACK_DAYS=${1:-6}

echo "Checking degraded operators in last $LOOKBACK_DAYS days..." >&2

# Get degraded operators and process them
oc get clusteroperators -o json | jq -r '.items[] |
  select(.status.conditions[]? | select(.type == "Degraded" and .status == "True" and .lastTransitionTime != null)) |
  {
    name: .metadata.name,
    timestamp: (.status.conditions[] | select(.type == "Degraded") | .lastTransitionTime),
    message: (.status.conditions[] | select(.type == "Degraded") | .message)
  } |
  "\(.name)|\(.timestamp)|\(.message)"' | while IFS='|' read -r operator timestamp message; do

  # Calculate age in days
  age_days=$(( ($(date +%s) - $(date -d "$timestamp" +%s)) / 86400 ))

  # Only output if within lookback period
  if [ $age_days -le $LOOKBACK_DAYS ]; then
    echo "$operator|$age_days|$message"
  fi
done

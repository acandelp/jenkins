#!/bin/bash
set -euo pipefail

LOOKBACK_DAYS=${1:-6}
LOOKBACK_SECONDS=$((LOOKBACK_DAYS * 86400))
NOW=$(date +%s)

echo "Checking degraded operators in last $LOOKBACK_DAYS days..." >&2

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Method 1: Check currently degraded operators
echo "  → Checking current operator status..." >&2
oc get clusteroperators -o json | jq -r '.items[] |
  select(.status.conditions[]? | select(.type == "Degraded" and .status == "True" and .lastTransitionTime != null)) |
  {
    name: .metadata.name,
    timestamp: (.status.conditions[] | select(.type == "Degraded") | .lastTransitionTime),
    message: (.status.conditions[] | select(.type == "Degraded") | .message)
  } |
  "\(.name)|\(.timestamp)|\(.message)"' | while IFS='|' read -r operator timestamp message; do

  # Calculate age in days
  timestamp_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$timestamp" "+%s" 2>/dev/null || date -d "$timestamp" +%s 2>/dev/null || echo 0)
  age_seconds=$((NOW - timestamp_epoch))
  age_days=$((age_seconds / 86400))

  # Only include if within lookback period
  if [ $age_seconds -le $LOOKBACK_SECONDS ] && [ $age_seconds -ge 0 ]; then
    echo "$operator|$age_days|$message" >> "$TMPDIR/current.txt"
  fi
done

# Method 2: Check events for historical degradations
echo "  → Checking historical events..." >&2
oc get events -A -o json 2>/dev/null | jq -r '.items[]? |
  select(.reason == "OperatorDegraded" or (.message | contains("degraded") or contains("Degraded"))) |
  select(.involvedObject.kind == "ClusterOperator" or .regarding.kind == "ClusterOperator") |
  {
    name: (if .involvedObject.name then .involvedObject.name else .regarding.name end),
    timestamp: (if .eventTime then .eventTime else .lastTimestamp end),
    message: .message
  } |
  select(.timestamp != null) |
  "\(.name)|\(.timestamp)|\(.message)"' 2>/dev/null | while IFS='|' read -r operator timestamp message; do

  # Calculate age
  timestamp_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$timestamp" "+%s" 2>/dev/null || date -d "$timestamp" +%s 2>/dev/null || echo 0)
  age_seconds=$((NOW - timestamp_epoch))
  age_days=$((age_seconds / 86400))

  # Only include if within lookback period
  if [ $age_seconds -le $LOOKBACK_SECONDS ] && [ $age_seconds -ge 0 ]; then
    echo "$operator|$age_days|$message" >> "$TMPDIR/events.txt"
  fi
done || true

echo "  → Consolidating results..." >&2

# Combine and deduplicate: prefer current status over events
# First output current degradations
if [ -f "$TMPDIR/current.txt" ]; then
  cat "$TMPDIR/current.txt" > "$TMPDIR/all.txt"
  # Get list of operators already in current
  cut -d'|' -f1 "$TMPDIR/current.txt" | sort -u > "$TMPDIR/current_ops.txt"
else
  touch "$TMPDIR/all.txt"
  touch "$TMPDIR/current_ops.txt"
fi

# Add historical events only if operator not in current
if [ -f "$TMPDIR/events.txt" ]; then
  while IFS='|' read -r operator age_days message; do
    # Check if operator is NOT in current list
    if ! grep -q "^${operator}$" "$TMPDIR/current_ops.txt" 2>/dev/null; then
      echo "$operator|$age_days|$message" >> "$TMPDIR/all.txt"
    fi
  done < "$TMPDIR/events.txt"
fi

# Output unique results sorted by age
if [ -f "$TMPDIR/all.txt" ] && [ -s "$TMPDIR/all.txt" ]; then
  sort -u "$TMPDIR/all.txt" | sort -t'|' -k2 -rn
fi

#!/bin/bash
set -euo pipefail

echo "Checking for firing alerts from Prometheus..." >&2

# Get token for Prometheus API access
TOKEN=$(oc -n openshift-monitoring sa get-token prometheus-k8s 2>/dev/null || oc create token prometheus-k8s -n openshift-monitoring --duration=10m 2>/dev/null)

# Query Prometheus for firing alerts
# Use the thanos-querier service which aggregates alerts from all Prometheus instances
RAW_JSON=$(oc -n openshift-monitoring exec -c prometheus prometheus-k8s-0 -- \
  curl -s -k -H "Authorization: Bearer $TOKEN" \
  'http://localhost:9090/api/v1/rules' 2>/dev/null | \
  jq '[.data.groups[].rules[] | select(.state == "firing" and .type == "alerting")] | unique_by(.labels.alertname)' 2>/dev/null || echo "[]")

# Count total firing alerts
TOTAL_COUNT=$(echo "$RAW_JSON" | jq '. | length' 2>/dev/null || echo "0")
echo "Total firing alerts in Prometheus: $TOTAL_COUNT" >&2

# Show all alert names (including Watchdog) for debugging
if [ "$TOTAL_COUNT" -gt 0 ]; then
  echo "Firing alert names found:" >&2
  echo "$RAW_JSON" | jq -r '.[].labels.alertname' 2>/dev/null | sort -u | while read -r name; do
    echo "  - $name" >&2
  done
fi

# Parse alerts (excluding Watchdog)
ALERTS=$(echo "$RAW_JSON" | jq -r '.[] |
  select(.labels.alertname != "Watchdog") |
  {
    name: .labels.alertname,
    severity: (.labels.severity // "unknown"),
    namespace: (.labels.namespace // "N/A"),
    summary: (.annotations.summary // .annotations.description // .annotations.message // "No description")
  } |
  "\(.name)|\(.severity)|\(.namespace)|\(.summary)"' 2>/dev/null || true)

# Output only if there are firing alerts (excluding Watchdog)
if [ -n "$ALERTS" ]; then
  echo "$ALERTS"
else
  echo "No firing alerts found (excluding Watchdog heartbeat)" >&2
fi

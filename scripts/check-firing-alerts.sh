#!/bin/bash
set -euo pipefail

echo "Checking for active firing alerts..." >&2

# Debug: Get raw JSON to see what we're working with
echo "Fetching raw alert data..." >&2
RAW_JSON=$(oc -n openshift-monitoring exec alertmanager-main-0 -c alertmanager -- \
  curl -s http://localhost:9093/api/v2/alerts 2>/dev/null || echo "[]")

# Debug: Show count of total alerts
TOTAL_COUNT=$(echo "$RAW_JSON" | jq '. | length' 2>/dev/null || echo "0")
echo "Total alerts in AlertManager: $TOTAL_COUNT" >&2

# Debug: Show all alert names (including Watchdog)
echo "Alert names found:" >&2
echo "$RAW_JSON" | jq -r '.[].labels.alertname' 2>/dev/null | sort -u | while read -r name; do
  echo "  - $name" >&2
done

# Parse alerts (excluding Watchdog)
ALERTS=$(echo "$RAW_JSON" | jq -r '.[] |
  select(.labels.alertname != "Watchdog") |
  {
    name: .labels.alertname,
    severity: (.labels.severity // "unknown"),
    namespace: (.labels.namespace // "N/A"),
    state: .status.state,
    summary: (.annotations.summary // .annotations.description // .annotations.message // "No description")
  } |
  "\(.name)|\(.severity)|\(.namespace)|\(.summary)"' 2>/dev/null || true)

# Output only if there are firing alerts (excluding Watchdog)
if [ -n "$ALERTS" ]; then
  echo "$ALERTS"
else
  echo "No firing alerts found (excluding Watchdog heartbeat)" >&2
fi

#!/bin/bash
set -euo pipefail

echo "Checking for active firing alerts..." >&2

# Try using amtool first (official AlertManager CLI tool)
ALERTS=$(oc -n openshift-monitoring exec alertmanager-main-0 -c alertmanager -- \
  amtool --alertmanager.url=http://localhost:9093 alert --output json 2>/dev/null | \
  jq -r '.[] |
  select(.labels.alertname != "Watchdog") |
  {
    name: .labels.alertname,
    severity: (.labels.severity // "unknown"),
    namespace: (.labels.namespace // "N/A"),
    summary: (.annotations.summary // .annotations.description // .annotations.message // "No description")
  } |
  "\(.name)|\(.severity)|\(.namespace)|\(.summary)"' 2>/dev/null || true)

# If amtool failed or no results, try direct API approach
if [ -z "$ALERTS" ]; then
  echo "Trying direct API approach..." >&2
  ALERTS=$(oc -n openshift-monitoring exec alertmanager-main-0 -c alertmanager -- \
    curl -s http://localhost:9093/api/v2/alerts 2>/dev/null | \
    jq -r '.[] |
    select(.status.state == "active" or .status.state == "firing") |
    select(.labels.alertname != "Watchdog") |
    {
      name: .labels.alertname,
      severity: (.labels.severity // "unknown"),
      namespace: (.labels.namespace // "N/A"),
      summary: (.annotations.summary // .annotations.description // .annotations.message // "No description")
    } |
    "\(.name)|\(.severity)|\(.namespace)|\(.summary)"' 2>/dev/null || true)
fi

# Output only if there are firing alerts (excluding Watchdog)
if [ -n "$ALERTS" ]; then
  echo "$ALERTS"
else
  echo "No firing alerts found (excluding Watchdog heartbeat)" >&2
fi

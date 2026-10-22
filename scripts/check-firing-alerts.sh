#!/bin/bash
set -euo pipefail

echo "Checking for active firing alerts..." >&2

# Try to get firing alerts from AlertManager
# Need to elevate to access openshift-monitoring namespace
ALERTS=$(oc -n openshift-monitoring exec alertmanager-main-0 -c alertmanager -- \
  curl -s http://localhost:9093/api/v2/alerts 2>/dev/null | \
  jq -r '.[] | select(.status.state == "active") |
  {
    name: .labels.alertname,
    severity: .labels.severity,
    namespace: .labels.namespace,
    summary: .annotations.summary,
    description: .annotations.description
  } |
  "\(.name)|\(.severity // "unknown")|\(.namespace // "N/A")|\(.summary // .description // "No description")"' || true)

# Output only if there are firing alerts
if [ -n "$ALERTS" ]; then
  echo "$ALERTS"
else
  echo "No firing alerts found" >&2
fi

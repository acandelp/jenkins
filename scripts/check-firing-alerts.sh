#!/bin/bash
set -euo pipefail

echo "Checking for firing alerts from Prometheus..." >&2

# Method 1: Try using oc get prometheusrule to get alert definitions and their states
echo "Attempting to query Prometheus rules..." >&2

# Get all PrometheusRule objects and check their alert states via oc
RAW_JSON=$(oc -n openshift-monitoring exec -c prometheus prometheus-k8s-0 -- \
  curl -s 'http://localhost:9090/api/v1/rules' 2>&1 || echo '{"status":"error"}')

echo "Raw response received (first 200 chars):" >&2
echo "$RAW_JSON" | head -c 200 >&2
echo "" >&2

# Check if we got valid JSON
if echo "$RAW_JSON" | jq -e '.status == "success"' >/dev/null 2>&1; then
  echo "Successfully queried Prometheus rules API" >&2

  # Extract firing alerts
  ALERTS_JSON=$(echo "$RAW_JSON" | jq '[.data.groups[].rules[] | select(.state == "firing" and .type == "alerting")]' 2>&1 || echo "[]")

  # Count total firing alerts
  TOTAL_COUNT=$(echo "$ALERTS_JSON" | jq '. | length' 2>/dev/null || echo "0")
  echo "Total firing alerts in Prometheus: $TOTAL_COUNT" >&2

  # Show all alert names (including Watchdog) for debugging
  if [ "$TOTAL_COUNT" -gt 0 ]; then
    echo "Firing alert names found:" >&2
    echo "$ALERTS_JSON" | jq -r '.[].labels.alertname' 2>/dev/null | sort -u | while read -r name; do
      echo "  - $name" >&2
    done

    # Parse alerts (excluding Watchdog)
    ALERTS=$(echo "$ALERTS_JSON" | jq -r '.[] |
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
      echo "No firing alerts found (only Watchdog heartbeat detected)" >&2
    fi
  else
    echo "No firing alerts found (excluding Watchdog heartbeat)" >&2
  fi
else
  echo "ERROR: Failed to query Prometheus API" >&2
  echo "Response: $RAW_JSON" >&2
  exit 1
fi

#!/bin/bash
set -euo pipefail

echo "Checking for firing alerts from Prometheus..." >&2

# Get a token for API access
echo "Getting authentication token..." >&2
TOKEN=$(oc whoami -t 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to get authentication token" >&2
  exit 1
fi

# Get the thanos-querier route (public endpoint)
echo "Looking for Thanos Querier route..." >&2
THANOS_ROUTE=$(oc -n openshift-monitoring get route thanos-querier -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

if [ -n "$THANOS_ROUTE" ]; then
  echo "Using Thanos Querier route: $THANOS_ROUTE" >&2

  # Query via the route (OAuth proxy protected)
  RAW_JSON=$(curl -s -k \
    -H "Authorization: Bearer $TOKEN" \
    "https://$THANOS_ROUTE/api/v1/rules" 2>&1 || echo '{"status":"error"}')
else
  echo "Thanos route not found, using port-forward method..." >&2

  # Start a temporary port-forward in the background
  oc port-forward -n openshift-monitoring svc/thanos-querier 9091:9091 >/dev/null 2>&1 &
  PF_PID=$!

  # Wait a moment for port-forward to establish
  sleep 3

  # Query via localhost
  RAW_JSON=$(curl -s -k \
    -H "Authorization: Bearer $TOKEN" \
    'https://localhost:9091/api/v1/rules' 2>&1 || echo '{"status":"error"}')

  # Kill the port-forward
  kill $PF_PID 2>/dev/null || true
fi

echo "Raw response received (first 300 chars):" >&2
echo "$RAW_JSON" | head -c 300 >&2
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

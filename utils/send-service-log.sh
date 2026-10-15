#!/bin/bash
set -euo pipefail

# Simple wrapper for sending service logs
# Usage: echo "DESCRIPTION" | ./send-service-log.sh CLUSTER_ID SEVERITY SUMMARY
# Or: ./send-service-log.sh CLUSTER_ID SEVERITY SUMMARY < description.txt

CLUSTER_ID=$1
SEVERITY=$2
SUMMARY=$3

# Read description from stdin
DESCRIPTION=$(cat)

echo "Sending Service Log to cluster $CLUSTER_ID..." >&2
echo "Severity: $SEVERITY" >&2
echo "Summary: $SUMMARY" >&2

# Build JSON payload using jq and pipe directly to ocm post
# ocm post reads JSON from stdin when no --body flag is provided
jq -n \
  --arg cluster_uuid "$CLUSTER_ID" \
  --arg severity "$SEVERITY" \
  --arg service_name "SREManualAction" \
  --arg summary "$SUMMARY" \
  --arg description "$DESCRIPTION" \
  '{
    cluster_uuid: $cluster_uuid,
    severity: $severity,
    service_name: $service_name,
    summary: $summary,
    description: $description
  }' | ocm post /api/service_logs/v1/cluster_logs

echo "✅ Service Log sent successfully!" >&2

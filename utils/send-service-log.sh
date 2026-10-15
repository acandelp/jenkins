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
echo "" >&2

# Build JSON payload using jq and pipe to ocm post
# Send both JSON and "y" confirmation to stdin using grouped commands
# Format response with jq for readability
{
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
    }'
  echo y
} | ocm post /api/service_logs/v1/cluster_logs | jq -r '
  if .items then
    .items[] |
    "✅ Service Log Created Successfully

📋 Details:
  • ID: \(.id)
  • Severity: \(.severity)
  • Summary: \(.summary)
  • Timestamp: \(.timestamp)
  • Event Stream: \(.event_stream_id)

The Service Log is now visible to the customer in OCM Console."
  else
    "✅ Service Log sent successfully!"
  end
'

echo "" >&2
echo "✅ Service Log sent successfully!" >&2

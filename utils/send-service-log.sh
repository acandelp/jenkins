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

ocm post /api/service_logs/v1/cluster_logs \
  --body="{
    \"cluster_uuid\": \"${CLUSTER_ID}\",
    \"severity\": \"${SEVERITY}\",
    \"service_name\": \"SREManualAction\",
    \"summary\": \"${SUMMARY}\",
    \"description\": \"${DESCRIPTION}\"
  }"

echo "✅ Service Log sent successfully!" >&2

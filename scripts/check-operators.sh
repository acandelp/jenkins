#!/bin/bash
set -euo pipefail

echo "Checking cluster operators status..." >&2

# Get currently degraded operators
oc get clusteroperators -o json | jq -r '
.items[] |
select(.status.conditions[]? | select(.type == "Degraded" and .status == "True")) |
{
  name: .metadata.name,
  message: (.status.conditions[] | select(.type == "Degraded") | .message)
} |
"\(.name)|\(.message)"'

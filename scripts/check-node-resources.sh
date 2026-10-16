#!/bin/bash
set -euo pipefail

THRESHOLD=${1:-70}

echo "Checking node resource usage (threshold: ${THRESHOLD}%)..." >&2

# Get node metrics and filter nodes exceeding threshold
# Output format: NODE_NAME|CPU_PERCENT|MEMORY_PERCENT
oc adm top nodes --no-headers | awk -v threshold="$THRESHOLD" '
{
    # Parse node name, CPU percentage, and memory percentage
    node_name = $1
    cpu_usage = $2
    cpu_percent = $3
    mem_usage = $4
    mem_percent = $5

    # Remove % symbol from percentages
    gsub(/%/, "", cpu_percent)
    gsub(/%/, "", mem_percent)

    # Check if either CPU or memory exceeds threshold
    if (cpu_percent >= threshold || mem_percent >= threshold) {
        print node_name "|" cpu_percent "|" mem_percent
    }
}'

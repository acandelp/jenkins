#!/bin/bash
set -euo pipefail

THRESHOLD=${1:-100}

echo "Checking node resource limits (threshold: ${THRESHOLD}%)..." >&2

# Get all nodes
nodes=$(oc get nodes -o name | sed 's|node/||')

for node in $nodes; do
    # Get node description and extract limits percentages
    describe_output=$(oc describe node "$node")

    # Extract CPU and Memory limits percentages from "Allocated resources" section
    # Look for lines like: cpu  500m (12%)  2000m (50%)
    # The second percentage is the Limits
    cpu_limit=$(echo "$describe_output" | \
        grep -A 10 "Allocated resources:" | \
        grep "^  cpu" | \
        awk '{print $4}' | \
        sed 's/[()%]//g' || echo "0")

    memory_limit=$(echo "$describe_output" | \
        grep -A 10 "Allocated resources:" | \
        grep "^  memory" | \
        awk '{print $4}' | \
        sed 's/[()%]//g' || echo "0")

    # Default to 0 if empty
    cpu_limit=${cpu_limit:-0}
    memory_limit=${memory_limit:-0}

    # Check if either limit exceeds threshold
    if (( $(echo "$cpu_limit >= $THRESHOLD" | bc -l) )) || \
       (( $(echo "$memory_limit >= $THRESHOLD" | bc -l) )); then
        echo "$node|$cpu_limit|$memory_limit"
    fi
done

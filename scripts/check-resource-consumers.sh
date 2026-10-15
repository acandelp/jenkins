#!/bin/bash
set -euo pipefail

TOP_N=${1:-5}

echo "Checking top $TOP_N resource consumers (6-day average)..." >&2

# Use current session token and thanos-querier for metrics access
PROM_TOKEN=$(oc whoami -t 2>/dev/null || echo "")
PROM_HOST=$(oc get route thanos-querier -n openshift-monitoring -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

# CPU
echo "CPU"
curl -s -k -H "Authorization: Bearer ${PROM_TOKEN}" \
  "https://${PROM_HOST}/api/v1/query?query=topk(${TOP_N},avg_over_time(namespace:container_cpu_usage:sum[6d]))" \
| jq -r '.data.result[] | "\(.metric.namespace)|\(.value[1])"'

# Memory
echo "MEMORY"
curl -s -k -H "Authorization: Bearer ${PROM_TOKEN}" \
  "https://${PROM_HOST}/api/v1/query?query=topk(${TOP_N},avg_over_time(namespace:container_memory_usage_bytes:sum[6d]))" \
| jq -r '.data.result[] | "\(.metric.namespace)|\(.value[1])"'

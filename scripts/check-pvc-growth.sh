#!/bin/bash
set -euo pipefail

GROWTH_THRESHOLD=${1:-20}

echo "Checking PVC growth > $GROWTH_THRESHOLD% in last 6 days..." >&2

PROM_TOKEN=$(oc sa get-token prometheus-k8s -n openshift-monitoring)
PROM_HOST=$(oc get route prometheus-k8s -n openshift-monitoring -o jsonpath='{.spec.host}')

query="((kubelet_volume_stats_used_bytes - kubelet_volume_stats_used_bytes offset 6d) / kubelet_volume_stats_used_bytes offset 6d) * 100"

curl -s -k -H "Authorization: Bearer ${PROM_TOKEN}" \
  "https://${PROM_HOST}/api/v1/query?query=${query}" \
| jq -r --arg threshold "$GROWTH_THRESHOLD" '
  .data.result[] |
  select(.value[1] | tonumber > ($threshold | tonumber)) |
  "\(.metric.namespace)|\(.metric.persistentvolumeclaim)|\(.value[1])"
'

#!/bin/bash
set -euo pipefail

DAYS_WARNING=${1:-60}

echo "Checking certificates expiring in < $DAYS_WARNING days..." >&2

oc get secrets -A -o json | jq -r '
  .items[] |
  select(.type == "kubernetes.io/tls") |
  select(.data."tls.crt" != null) |
  "\(.metadata.namespace)/\(.metadata.name) \(.data."tls.crt")"
' | while read namespace_name cert; do
  namespace=$(echo $namespace_name | cut -d'/' -f1)
  name=$(echo $namespace_name | cut -d'/' -f2)

  expiry=$(echo $cert | base64 -d | openssl x509 -noout -enddate 2>/dev/null | cut -d'=' -f2)
  if [ ! -z "$expiry" ]; then
    days_left=$(( ($(date -d "$expiry" +%s) - $(date +%s)) / 86400 ))

    if [ $days_left -lt $DAYS_WARNING ] && [ $days_left -gt 0 ]; then
      echo "$namespace|$name|$days_left|$expiry"
    fi
  fi
done

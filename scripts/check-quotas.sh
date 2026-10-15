#!/bin/bash
set -euo pipefail

USAGE_THRESHOLD=${1:-85}

echo "Checking resource quotas > $USAGE_THRESHOLD%..." >&2

oc get resourcequota -A -o json | jq -r '
  .items[] |
  .metadata.namespace as $ns |
  .metadata.name as $quota |
  .status.hard as $hard |
  .status.used as $used |
  $hard | to_entries[] |
  select($used[.key] != null) |
  "\($ns)|\($quota)|\(.key)|\($used[.key])|\(.value)"
' | while read line; do
  IFS='|' read -r ns quota resource used hard <<< "$line"

  used_num=$(echo $used | sed 's/[^0-9]//g')
  hard_num=$(echo $hard | sed 's/[^0-9]//g')

  if [ ! -z "$used_num" ] && [ ! -z "$hard_num" ] && [ $hard_num -gt 0 ]; then
    percentage=$((used_num * 100 / hard_num))

    if [ $percentage -gt $USAGE_THRESHOLD ]; then
      echo "$ns|$quota|$resource|$percentage|$used|$hard"
    fi
  fi
done

#!/bin/bash
set -euo pipefail

echo "Checking available cluster upgrades..." >&2

current=$(oc get clusterversion version -o jsonpath='{.status.desired.version}')
channel=$(oc get clusterversion version -o jsonpath='{.spec.channel}')
available=$(oc get clusterversion version -o jsonpath='{.status.availableUpdates[*].version}')

if [ ! -z "$available" ]; then
  echo "CURRENT|$current"
  echo "CHANNEL|$channel"
  for version in $available; do
    echo "AVAILABLE|$version"
  done
fi

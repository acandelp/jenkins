#!/bin/bash
# Obtiene todos los Cluster IDs de un Account Number
# Usage: ./get-clusters-by-account.sh <account_number> [format]
#   format: 'list' (default) - one cluster ID per line
#           'json' - JSON array
#           'details' - cluster_id|name|state

set -euo pipefail

ACCOUNT_NUMBER="${1:-}"
FORMAT="${2:-list}"

if [ -z "$ACCOUNT_NUMBER" ]; then
    echo "Usage: $0 <account_number> [format]" >&2
    echo "  format: list (default), json, details" >&2
    exit 1
fi

# Find organization ID from account number
ORG_ID=$(ocm get "/api/accounts_mgmt/v1/organizations?search=ebs_account_id='$ACCOUNT_NUMBER'" 2>/dev/null | jq -r '.items[0].id')

if [ -z "$ORG_ID" ] || [ "$ORG_ID" = "null" ]; then
    echo "Error: No organization found with Account Number: $ACCOUNT_NUMBER" >&2
    exit 1
fi

# Get all cluster IDs for this organization
CLUSTER_IDS=$(ocm get "/api/accounts_mgmt/v1/subscriptions?search=organization_id='$ORG_ID'" 2>/dev/null | \
    jq -r '.items[] | .cluster_id' | grep -v "^null$" || true)

if [ -z "$CLUSTER_IDS" ]; then
    echo "Error: No clusters found for Account Number: $ACCOUNT_NUMBER" >&2
    exit 1
fi

case "$FORMAT" in
    list)
        # One cluster ID per line
        echo "$CLUSTER_IDS"
        ;;
    json)
        # JSON array
        echo "$CLUSTER_IDS" | jq -R -s -c 'split("\n") | map(select(length > 0))'
        ;;
    details)
        # cluster_id|name|state format
        echo "$CLUSTER_IDS" | while read -r cluster_id; do
            if [ -n "$cluster_id" ]; then
                cluster_info=$(ocm get "/api/clusters_mgmt/v1/clusters/$cluster_id" 2>/dev/null || echo "{}")
                cluster_name=$(echo "$cluster_info" | jq -r '.name // "UNKNOWN"')
                cluster_state=$(echo "$cluster_info" | jq -r '.state // "UNKNOWN"')
                echo "${cluster_id}|${cluster_name}|${cluster_state}"
            fi
        done
        ;;
    *)
        echo "Error: Invalid format: $FORMAT" >&2
        echo "Valid formats: list, json, details" >&2
        exit 1
        ;;
esac

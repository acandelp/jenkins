#!/bin/bash
set -euo pipefail

echo "Checking for customer workloads on control plane nodes..." >&2

# Get control plane nodes (try both labels for compatibility)
control_plane_nodes=$(oc get nodes \
    -l 'node-role.kubernetes.io/master' \
    -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "$control_plane_nodes" ]; then
    # Try alternative label (used in some OpenShift versions)
    control_plane_nodes=$(oc get nodes \
        -l 'node-role.kubernetes.io/control-plane' \
        -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
fi

if [ -z "$control_plane_nodes" ]; then
    echo "⚠️  No control plane nodes found - this might be a Hosted Control Plane cluster" >&2
    exit 0
fi

echo "Found control plane nodes: $control_plane_nodes" >&2

# For each control plane node, get pods and filter out system namespaces
for node in $control_plane_nodes; do
    oc get pods --all-namespaces \
        --field-selector spec.nodeName="$node" \
        -o json | jq -r '
        .items[] |
        select(
            (.metadata.namespace | startswith("openshift-") | not) and
            (.metadata.namespace | startswith("kube-") | not) and
            (.metadata.namespace != "default")
        ) |
        "\(.metadata.namespace)|\(.metadata.name)|\(.spec.nodeName)"
    '
done

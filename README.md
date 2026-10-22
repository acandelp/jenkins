# Jenkins SRE Automation Pipelines

This repository contains Jenkins pipelines for automated SRE monitoring and alerting on OpenShift clusters.

## Overview

These pipelines automatically check various aspects of cluster health and send Service Logs to customers via OCM (OpenShift Cluster Manager).

## Prerequisites

- Jenkins with access to:
  - OCM CLI (`ocm`)
  - Backplane CLI (`ocm backplane`)
  - OpenShift CLI (`oc`)
  - `jq` for JSON processing
- Proper authentication configured for OCM

## Available Pipelines

### 1. Node Resource Monitoring (`Jenkinsfile-node-resources`)

**Purpose**: Monitor node-level CPU and memory usage and alert when nodes exceed defined thresholds.

**Parameters**:
- `CLUSTER_ID` (required): The cluster ID to check
- `THRESHOLD` (default: 70): Resource usage threshold percentage

**Behavior**:
- Checks all nodes using `oc adm top nodes`
- If any node exceeds the threshold (CPU OR memory):
  - Sends a **Moderate** Service Log listing affected nodes with their usage percentages
  - Sets build status to UNSTABLE
- If all nodes are below the threshold:
  - No Service Log sent (healthy state)
  - Sets build status to SUCCESS

**Example Service Log**:

*High Usage Detected:*
```
Severity: Moderate
Summary: High Node Resource Usage Detected (2 node(s))
Description: Detected 2 node(s) exceeding 70% resource usage threshold: 
worker-1 (CPU: 85%, Memory: 72%), worker-3 (Memory: 78%).
```

*Note: No Service Log is sent when all nodes are below threshold (healthy state).*

**Usage**:
```bash
# Run with default 70% threshold
CLUSTER_ID=<cluster-id> ./Jenkinsfile-node-resources

# Run with custom 80% threshold
CLUSTER_ID=<cluster-id> THRESHOLD=80 ./Jenkinsfile-node-resources
```

---

### 2. Node Resource Limits Check (`Jenkinsfile-node-limits`)

**Purpose**: Monitor node-level resource limits (CPU and memory) and alert when allocations exceed capacity.

**Parameters**:
- `CLUSTER_ID` (required): The cluster ID to check
- `THRESHOLD` (default: 100): Resource limits threshold percentage

**Behavior**:
- Checks all nodes using `oc describe nodes` to analyze allocated resource limits
- If any node has limits exceeding the threshold (CPU OR memory):
  - Sends a **Moderate** Service Log listing affected nodes with their limit percentages
  - Sets build status to UNSTABLE
- If all nodes have limits below the threshold:
  - No Service Log sent (healthy state)
  - Sets build status to SUCCESS

**Example Service Log**:

*Limits Exceeded:*
```
Severity: Moderate
Summary: Node Resource Limits Exceeded (2 node(s))
Description: Detected 2 node(s) with resource limits exceeding 100%: 
worker-1 (CPU: 125%, Memory: 110%), worker-2 (CPU: 105%).
```

*Note: No Service Log is sent when all nodes are below threshold (healthy state).*

**Usage**:
```bash
# Run with default 100% threshold
CLUSTER_ID=<cluster-id> ./Jenkinsfile-node-limits

# Run with custom 90% threshold
CLUSTER_ID=<cluster-id> THRESHOLD=90 ./Jenkinsfile-node-limits
```

---

### 3. Degraded Operators Check (`Jenkinsfile-degraded-operators`)

**Purpose**: Monitor cluster operators and alert when any are in a degraded state.

**Parameters**:
- `CLUSTER_ID` (required): The cluster ID to check

**Behavior**:
- Checks all cluster operators for degraded status
- If degraded operators found:
  - Sends a **Moderate** Service Log listing affected operators
  - Sets build status to UNSTABLE
- If all operators healthy:
  - No Service Log sent (healthy state)
  - Sets build status to SUCCESS

---

### 3.1. Active Firing Alerts Monitor (`Jenkinsfile-firing-alerts`)

**Purpose**: Proactively detect and report active firing alerts from Prometheus AlertManager.

**Parameters**:
- `CLUSTER_ID` (required): The cluster ID to check
- `MIN_SEVERITY` (default: warning): Minimum alert severity to report (info|warning|critical)

**Behavior**:
- Uses `ocm backplane elevate` to access openshift-monitoring namespace
- Queries AlertManager API for currently active/firing alerts
- Filters alerts by severity level
- Groups alerts by severity (critical > warning > info)
- If firing alerts found:
  - Sends **Moderate** Service Log if critical alerts present
  - Sends **Low** Service Log if only warnings/info
  - Lists up to 10 alerts with details (shows more count if applicable)
  - Sets build status to UNSTABLE
- If no alerts firing:
  - No Service Log sent (healthy state)
  - Sets build status to SUCCESS

**Example Service Logs**:

*Critical Alerts Detected:*
```
Severity: Moderate
Summary: 2 Critical Alert(s) Firing
Description: The cluster has 2 active firing alert(s):
🔴 KubePodCrashLooping (customer-app): Pod customer-app/frontend-xyz is crash looping
🔴 etcdHighFsyncDurations (openshift-etcd): etcd fsync duration is too high

Our SRE team is monitoring these alerts. If you are experiencing service 
disruptions, please open a support case referencing these alerts.
```

*Warning Alerts Only:*
```
Severity: Low
Summary: 3 Warning Alert(s) Firing
Description: The cluster has 3 active firing alert(s):
🟡 NodeFilesystemAlmostOutOfSpace (N/A): Node worker-2 filesystem is 87% full
🟡 PrometheusTargetSyncFailure (openshift-monitoring): Prometheus target sync failing
ℹ️ InfoAlert (default): Informational alert

Our SRE team is monitoring these alerts...
```

*Note: No Service Log is sent when no alerts are firing (healthy state).*

**Elevation Command**:
```bash
ocm backplane elevate "Automated SRE check: querying AlertManager for active firing alerts to send proactive Service Log to customer"
```

**Usage**:
```bash
# Run with default settings (warning severity threshold)
CLUSTER_ID=<cluster-id> ./Jenkinsfile-firing-alerts

# Only report critical alerts
CLUSTER_ID=<cluster-id> MIN_SEVERITY=critical ./Jenkinsfile-firing-alerts

# Include info-level alerts
CLUSTER_ID=<cluster-id> MIN_SEVERITY=info ./Jenkinsfile-firing-alerts
```

**Special Notes**:
- Requires elevated permissions (automatically requested via `ocm backplane elevate`)
- Alert descriptions come from Prometheus annotations (summary or description)
- Alerts are sorted by severity (critical first)
- Namespaces shown when available (shows "N/A" for cluster-scoped alerts)

---

### 4. Resource Consumers Report (`Jenkinsfile-resource-consumers`)

**Purpose**: Generate informational reports about top resource-consuming namespaces.

**Parameters**:
- `CLUSTER_ID` (required): The cluster ID to check
- `TOP_N` (default: 5): Number of top consumers to report

**Behavior**:
- Queries Prometheus for namespace-level resource usage
- Generates informational Service Log with top CPU and memory consumers
- Always sends **Low** severity (informational only)

---

### 5. Account-Based Resource Consumers (`Jenkinsfile-account-resource-consumers`)

**Purpose**: Generate resource consumption reports for all clusters in an OCM account.

**Parameters**:
- `ACCOUNT_ID` (required): The OCM account ID
- `TOP_N` (default: 5): Number of top consumers per cluster

---

## Project Structure

```
jenkins/
├── Jenkinsfile-*                      # Pipeline definitions
├── scripts/                           # Check scripts
│   ├── check-node-resources.sh       # Node resource usage check
│   ├── check-node-limits.sh          # Node resource limits check
│   ├── check-operators.sh            # Degraded operators check
│   ├── check-firing-alerts.sh        # Active firing alerts check
│   ├── check-resource-consumers.sh   # Resource consumption report
│   └── ...
├── utils/                             # Utility scripts
│   └── send-service-log.sh           # Service Log submission utility
└── config/                            # Configuration files
```

## Service Log Format

All pipelines use the standard Service Log format:

```json
{
  "cluster_uuid": "<cluster-id>",
  "severity": "Low|Warning|Error|Critical",
  "service_name": "SREManualAction",
  "summary": "<short-summary>",
  "description": "<detailed-description>"
}
```

**Severity Levels**:
- **Low**: Informational, no action required
- **Warning**: Attention recommended, monitoring in progress
- **Error**: Issue detected, SRE investigating
- **Critical**: Urgent issue, immediate attention required

## Adding New Pipelines

To add a new monitoring pipeline:

1. **Create a check script** in `scripts/`:
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   echo "Checking something..." >&2
   
   # Output results in parseable format (e.g., NAME|VALUE)
   # Only output findings, empty output = healthy
   ```

2. **Create a Jenkinsfile**:
   - Follow the pattern in existing Jenkinsfiles
   - Include: Checkout, Backplane Login, Setup, Check, Logout
   - Handle both positive (healthy) and negative (issue) cases
   - Send appropriate Service Logs for each case

3. **Test locally**:
   ```bash
   # Test the script
   ocm backplane login <cluster-id>
   ./scripts/your-check-script.sh
   
   # Test Service Log submission
   echo "Test message" | ./utils/send-service-log.sh <cluster-id> Low "Test"
   ```

## Best Practices

1. **Send Service Logs only for issues**: Only send Service Logs when problems are detected to reduce customer notification noise
2. **Be customer-friendly**: Write clear, actionable messages
3. **Include context**: Specify what was checked, what threshold was used, and what was found
4. **Provide guidance**: Tell customers what action is recommended or what SRE is doing
5. **Use appropriate severity**: 
   - **Moderate**: For issues requiring attention (resource limits exceeded, critical alerts, degraded operators)
   - **Low**: For warnings and informational alerts (warning-level alerts, high but not critical usage)
6. **Make scripts robust**: Use `set -euo pipefail` and handle errors gracefully
7. **Clean up**: Always logout from backplane in the `post` section

## Troubleshooting

### Pipeline fails with "CLUSTER_ID parameter is required"
Ensure you're passing the CLUSTER_ID parameter when triggering the pipeline.

### Pipeline fails with "ocm: command not found"
Verify OCM CLI is installed and in the PATH configured in the pipeline environment.

### Script execution permission denied
Run: `chmod +x scripts/*.sh utils/*.sh`

### Backplane login fails
- Verify OCM authentication is configured
- Check cluster ID is correct
- Ensure you have access to the cluster

### Service Log submission fails
- Verify OCM credentials are valid
- Check network connectivity to OCM API
- Review error message from `send-service-log.sh`

## Contributing

When adding new pipelines or modifying existing ones:

1. Follow the existing patterns and conventions
2. Test thoroughly on a test cluster first
3. Update this README with new pipeline documentation
4. Add appropriate comments in code
5. Ensure Service Log messages are clear and customer-friendly

## License

Internal Red Hat SRE tooling.

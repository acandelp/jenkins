# OpenShift Cluster Health Monitoring - Jenkins Pipelines

Automated cluster health checks with detailed Service Log notifications to customers.

## 📋 Overview

This repository contains Jenkins pipelines that proactively monitor OpenShift clusters and send detailed Service Logs to customers about potential issues **before they become critical**.

**Reporting Period**: Every 6 days (configurable via Jenkins triggers)

## 🗂️ Repository Structure

```
jenkins/
├── config/
│   └── thresholds.properties        # Configuration thresholds
├── scripts/
│   ├── check-certificates.sh        # SSL/TLS certificate expiration check
│   ├── check-pvc-growth.sh          # PVC growth trend analysis
│   ├── check-quotas.sh              # Resource quota usage check
│   ├── check-pod-restarts.sh        # Pod stability check
│   ├── check-oom-events.sh          # Out of Memory events check
│   ├── check-upgrades.sh            # Available cluster upgrades
│   ├── check-operators.sh           # Degraded operators check
│   └── check-resource-consumers.sh  # Resource consumption report
├── utils/
│   ├── send-service-log.sh          # Service Log sender utility
│   └── get-clusters-by-account.sh   # Get all clusters for an account
├── Jenkinsfile-*                    # Individual pipeline definitions (per cluster)
├── Jenkinsfile-account-*            # Account-based pipelines (all clusters)
└── ACCOUNT_BASED_CHECKS.md          # Account-based checks documentation
```

## 🔍 Available Health Checks

### 1. Certificate Expiration (`Jenkinsfile-certificates`)
**What it checks**: SSL/TLS certificates expiring within 60 days  
**Severity**: Warning  
**Why**: Prevent service interruptions from expired certificates  
**Action**: Coordinate certificate renewal with teams

### 2. PVC Growth (`Jenkinsfile-pvc-growth`)
**What it checks**: PVCs with >20% growth in 6 days  
**Severity**: Warning  
**Why**: Prevent storage exhaustion and pod evictions  
**Action**: Review storage trends and plan capacity expansion

### 3. Resource Quotas (`Jenkinsfile-quotas`)
**What it checks**: Quotas exceeding 85% capacity  
**Severity**: Warning  
**Why**: Prevent deployment failures when quotas hit 100%  
**Action**: Review and potentially increase quotas

### 4. Pod Restarts (`Jenkinsfile-pod-restarts`)
**What it checks**: Pods with >10 restarts  
**Severity**: Warning  
**Why**: Identify stability issues before they cause outages  
**Action**: Investigate logs and health checks

### 5. OOM Events (`Jenkinsfile-oom-events`)
**What it checks**: OOMKilled events in last 6 days  
**Severity**: Warning  
**Why**: Memory issues cause data loss and instability  
**Action**: Increase memory limits or fix memory leaks

### 6. Available Upgrades (`Jenkinsfile-available-upgrades`)
**What it checks**: New OpenShift versions available  
**Severity**: Info  
**Why**: Keep customers informed about upgrade options  
**Action**: Plan upgrade during maintenance window

### 7. Degraded Operators (`Jenkinsfile-degraded-operators`)
**What it checks**: Cluster operators in degraded state  
**Severity**: Warning  
**Why**: Degraded operators block upgrades and impact functionality  
**Action**: Investigate and resolve operator issues

### 8. Resource Consumers (`Jenkinsfile-resource-consumers`)
**What it checks**: Top 5 CPU/Memory consuming namespaces  
**Severity**: Info  
**Why**: Capacity planning and cost optimization  
**Action**: Right-size resources and optimize usage

## 🏢 Account-Based Checks

**NEW!** Run health checks across **all clusters** belonging to a specific customer account.

Instead of checking clusters one at a time, you can now execute health checks on all clusters that share the same Account Number (EBS Account ID).

### Quick Example

```bash
# Traditional approach: Check one cluster
Build with Parameters:
  - CLUSTER_ID: 2dhfsqa1ejpmfvaaaao0v6etmhq2ih10

# NEW: Account-based approach - Check all clusters for account 11800160
Build with Parameters:
  - ACCOUNT_NUMBER: 11800160
  - EXECUTION_MODE: parallel
```

### Available Account-Based Pipelines

| Pipeline | Description | Use Case |
|----------|-------------|----------|
| `Jenkinsfile-account-resource-consumers` | Check resource usage across all account clusters | Quarterly capacity review |
| `Jenkinsfile-account-template` | Template for creating custom account checks | Build your own |

### Key Features

✅ **Automatic cluster discovery** - Finds all clusters for an account  
✅ **Parallel or sequential execution** - Choose based on cluster count  
✅ **Error isolation** - Failed clusters don't block others  
✅ **Automatic session cleanup** - Backplane sessions always closed  

### Getting Started

```bash
# 1. Find account number from a cluster
ocm describe cluster <cluster-id> | grep AccountNumber

# 2. Run account-based check
Build Job: Account-Resource-Consumers
Parameters:
  ACCOUNT_NUMBER: 11800160
  TOP_N: 5
  EXECUTION_MODE: sequential
```

**📖 Full Documentation**: See [ACCOUNT_BASED_CHECKS.md](ACCOUNT_BASED_CHECKS.md) for:
- Creating custom account-based checks
- Template customization guide
- Performance considerations
- Troubleshooting

## ⚙️ Configuration

### Thresholds Configuration

Edit `config/thresholds.properties` to customize warning thresholds:

```properties
CERT_DAYS_WARNING=60          # Certificate expiration warning (days)
PVC_GROWTH_THRESHOLD=20       # PVC growth warning (percentage)
QUOTA_USAGE_THRESHOLD=85      # Quota usage warning (percentage)
POD_RESTART_THRESHOLD=10      # Pod restart count warning
LOOKBACK_DAYS=6               # Historical analysis period
TOP_N_CONSUMERS=5             # Number of top consumers to report
```

## 🚀 Jenkins Setup

### Create Jenkins Jobs

For each `Jenkinsfile-*`, create a corresponding Jenkins job:

1. **New Item** → **Pipeline**
2. **Pipeline** → **Pipeline script from SCM**
3. **SCM**: Git
4. **Repository URL**: `<your-repo-url>`
5. **Script Path**: `Jenkinsfile-certificates` (or respective file)

### Job Names (Suggested)

- `cluster-health-certificates`
- `cluster-health-pvc-growth`
- `cluster-health-quotas`
- `cluster-health-pod-restarts`
- `cluster-health-oom-events`
- `cluster-health-upgrades`
- `cluster-health-operators`
- `cluster-health-resources`

### Schedule (Cron Trigger)

Add to each Jenkinsfile or configure in Jenkins UI:

```groovy
triggers {
    cron('0 8 */6 * *')  // Every 6 days at 8 AM
}
```

### Parameters

Each job requires:
- **CLUSTER_ID**: Target cluster UUID (required)
- **Threshold parameters**: Override defaults if needed

## 🧪 Testing Locally

Test scripts individually before running in Jenkins:

```bash
# Make scripts executable
chmod +x scripts/*.sh utils/*.sh

# Test certificate check
./scripts/check-certificates.sh 60

# Test PVC growth check
./scripts/check-pvc-growth.sh 20

# Test quotas check
./scripts/check-quotas.sh 85

# etc...
```

## 📤 Service Log Format

Each check sends a detailed Service Log with:

1. **Summary**: High-level overview of findings
2. **Details**: Specific items found (namespaces, resources, etc.)
3. **Impact**: Why this matters and potential consequences
4. **Recommended Actions**: Specific steps to resolve
5. **Context**: Background information and best practices

Example Service Log structure:

```
SSL/TLS Certificate Expiration Alert

SUMMARY:
Found 3 certificate(s) expiring within the next 60 days.

CERTIFICATES EXPIRING:
• Namespace: myapp-prod
  Secret: api-tls-cert
  Days Remaining: 45 days
  Expiration Date: 2026-11-29

IMPACT:
Certificate expiration can cause service interruptions...

RECOMMENDED ACTIONS:
1. Verify certificate renewal process is in place
2. Coordinate certificate renewal with application teams
...
```

## 🔐 Required Permissions

Jenkins needs:

- **Cluster access**: `oc` CLI authenticated to target cluster
- **OCM access**: `ocm` CLI authenticated for Service Logs
- **Prometheus access**: Service account token for metrics queries

```bash
# Test cluster access
oc whoami

# Test OCM access
ocm whoami

# Test Prometheus access
oc sa get-token prometheus-k8s -n openshift-monitoring
```

## 📊 Monitoring Pipeline Health

Check pipeline execution:

```bash
# View Jenkins job status
# From Jenkins UI: Build History

# Check Service Logs sent
ocm get /api/service_logs/v1/cluster_logs \
  --parameter search="cluster_uuid='<cluster-id>'"
```

## 🛠️ Customization

### Add New Check

1. Create script in `scripts/check-<name>.sh`
2. Create `Jenkinsfile-<name>` with detailed messaging
3. Add to config if needed
4. Create Jenkins job
5. Update this README

### Modify Thresholds

Edit `config/thresholds.properties` and restart jobs.

### Change Reporting Frequency

Modify cron trigger:
- `0 8 */3 * *` - Every 3 days at 8 AM
- `0 8 */7 * *` - Every 7 days at 8 AM
- `0 8 1 * *` - 1st of every month at 8 AM

## 📝 Service Log Best Practices

✅ **DO**:
- Provide specific, actionable recommendations
- Include context and impact
- Use appropriate severity (Info/Warning/Error)
- Format for readability
- Include commands customers can run

❌ **DON'T**:
- Send vague alerts without details
- Over-alert on minor issues
- Use Critical severity for preventive notifications
- Send duplicate Service Logs
- Include sensitive data (tokens, passwords)

## 🆘 Troubleshooting

### Pipeline Fails

```bash
# Check cluster connectivity
oc whoami
oc get clusterversion

# Check script permissions
ls -la scripts/
# Should show: -rwxr-xr-x

# Run script manually
./scripts/check-certificates.sh 60
```

### No Data Returned

- **Prometheus queries**: Check prometheus-k8s is accessible
- **Events**: May not have events in lookback period (normal)
- **Quotas**: No quotas exceeding threshold (normal)

### Service Log Not Sent

```bash
# Test OCM connectivity
ocm whoami

# Test Service Log manually
./utils/send-service-log.sh "<cluster-id>" "Info" "Test" "Test message"
```

## 📚 References

- [OpenShift Monitoring](https://docs.openshift.com/container-platform/latest/monitoring/monitoring-overview.html)
- [Service Logs API](https://github.com/openshift/ops-sop/blob/master/v4/knowledge_base/service_log.md)
- [OCM CLI](https://github.com/openshift-online/ocm-cli)

## 🤝 Contributing

1. Test locally before committing
2. Ensure scripts are idempotent
3. Update README for new checks
4. Follow existing Service Log format
5. Add thresholds to config file

## 📄 License

Internal Red Hat SRE tooling.

---

**Last Updated**: 2026-10-15  
**Maintained By**: Red Hat SRE Team

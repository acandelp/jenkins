# Account-Based Cluster Checks

Execute health checks across **all clusters** belonging to a specific Account Number.

## 🎯 Overview

Instead of checking one cluster at a time, you can now run health checks across all clusters that belong to a specific customer account (identified by EBS Account Number).

## 📦 Components

### 1. Utility Script: `get-clusters-by-account.sh`

**Location**: `utils/get-clusters-by-account.sh`

**Purpose**: Retrieves all cluster IDs for a given Account Number

**Usage**:

```bash
# List format (one cluster ID per line)
./utils/get-clusters-by-account.sh 11800160

# JSON array format
./utils/get-clusters-by-account.sh 11800160 json

# Detailed format (cluster_id|name|state)
./utils/get-clusters-by-account.sh 11800160 details
```

**Example Output** (details format):
```
2dhfsqa1ejpmfvaaaao0v6etmhq2ih10|eu-prd-01|ready
2e1gfqb350ktnq43fdq860r9vgf47o9g|eu-prd-02|ready
2e4qenv9dchf6q6sh3mi71lgcjqhs61j|us-prd-01|ready
```

### 2. Example Jenkinsfile: `Jenkinsfile-account-resource-consumers`

**Purpose**: Demonstrates how to run resource consumption checks across all clusters in an account

**Parameters**:
- `ACCOUNT_NUMBER` (string, required): EBS Account ID (e.g., "11800160")
- `TOP_N` (string, default: "5"): Number of top consumers to report
- `EXECUTION_MODE` (choice: sequential/parallel): How to execute checks

**Execution Modes**:
- **Sequential**: Checks clusters one by one (safer, slower)
- **Parallel**: Checks all clusters simultaneously (faster, more resource-intensive)

## 🚀 Quick Start

### Step 1: Find Account Number

```bash
# Get account number from a cluster
ocm describe cluster <cluster-id> | grep AccountNumber
```

**Example Output**:
```
AccountNumber:          11800160
```

### Step 2: Create Jenkins Job

1. Go to Jenkins → New Item
2. Name: `Account-Resource-Consumers`
3. Type: Pipeline
4. Pipeline script from SCM:
   - SCM: Git
   - Repository URL: `<your-repo-url>`
   - Script Path: `Jenkinsfile-account-resource-consumers`
5. Save

### Step 3: Run the Job

1. Click "Build with Parameters"
2. Enter:
   - **ACCOUNT_NUMBER**: `11800160`
   - **TOP_N**: `5`
   - **EXECUTION_MODE**: `sequential` (for first run)
3. Click "Build"

### Step 4: Monitor Execution

The pipeline will:
1. ✅ Validate the account number
2. 📋 Retrieve all clusters for the account
3. 🔍 Filter only clusters in `ready` state
4. 🚀 Execute resource consumption checks on each cluster
5. 📧 Send Service Logs to customers for each cluster

**Console Output Example**:
```
✅ Found 15 total clusters, 12 in ready state
  - 2dhfsqa1ejpmfvaaaao0v6etmhq2ih10 (eu-prd-01)
  - 2e1gfqb350ktnq43fdq860r9vgf47o9g (eu-prd-02)
  - 2e4qenv9dchf6q6sh3mi71lgcjqhs61j (us-prd-01)
  ...

🔍 Checking cluster: eu-prd-01 (2dhfsqa1ejpmfvaaaao0v6etmhq2ih10)
ℹ️  Resource consumption report generated for eu-prd-01
✅ Report sent for eu-prd-01

🔍 Checking cluster: eu-prd-02 (2e1gfqb350ktnq43fdq860r9vgf47o9g)
ℹ️  Resource consumption report generated for eu-prd-02
✅ Report sent for eu-prd-02
...

✅ Resource consumption reports completed for all clusters in Account 11800160
```

## 🔧 Creating Account-Based Checks for Other Health Checks

You can adapt this pattern for any of the existing health checks:

### Template Pattern

```groovy
// 1. Get clusters from account
def clusters = sh(
    script: "./utils/get-clusters-by-account.sh ${params.ACCOUNT_NUMBER} details",
    returnStdout: true
).trim().split('\n')

// 2. Filter ready clusters
def readyClusters = clusters.findAll { it.split('\\|')[2] == 'ready' }

// 3. Run check on each cluster
readyClusters.each { clusterLine ->
    def parts = clusterLine.split('\\|')
    def clusterId = parts[0]
    def clusterName = parts[1]

    // Login to cluster
    sh "ocm backplane login ${clusterId}"

    // Run your specific check
    sh "./scripts/check-YOUR-CHECK.sh"

    // Send service log
    sh "cat message.txt | ./utils/send-service-log.sh '${clusterId}' 'Warning' 'Your Title'"

    // Logout
    sh "ocm backplane logout || true"
}
```

### Example: Account-Based Certificate Check

Create `Jenkinsfile-account-certificates`:

```groovy
pipeline {
    agent any

    parameters {
        string(name: 'ACCOUNT_NUMBER', defaultValue: '', description: 'Account Number')
        choice(name: 'EXECUTION_MODE', choices: ['sequential', 'parallel'])
    }

    stages {
        stage('Get Clusters') {
            steps {
                script {
                    def clusters = sh(
                        script: "./utils/get-clusters-by-account.sh ${params.ACCOUNT_NUMBER} details",
                        returnStdout: true
                    ).trim()

                    env.CLUSTERS_JSON = convertClustersToJson(clusters)
                }
            }
        }

        stage('Check Certificates') {
            steps {
                script {
                    def clusters = parseJsonClusters(env.CLUSTERS_JSON)

                    clusters.each { cluster ->
                        sh "ocm backplane login ${cluster.id}"
                        sh "./scripts/check-certificates.sh"
                        sh "./utils/send-service-log.sh '${cluster.id}' 'Warning' 'Certificate Expiration'"
                        sh "ocm backplane logout || true"
                    }
                }
            }
        }
    }
}
```

## 📊 Supported Health Checks

You can create account-based versions for all existing checks:

| Check Type | Script | Recommended Mode |
|------------|--------|------------------|
| Certificates | `check-certificates.sh` | Sequential |
| PVC Growth | `check-pvc-growth.sh` | Sequential |
| Resource Quotas | `check-quotas.sh` | Parallel |
| Pod Restarts | `check-pod-restarts.sh` | Parallel |
| OOM Events | `check-oom-events.sh` | Parallel |
| Available Upgrades | `check-upgrades.sh` | Parallel |
| Degraded Operators | `check-operators.sh` | Sequential |
| Resource Consumers | `check-resource-consumers.sh` | Parallel |

**Sequential vs Parallel**:
- **Sequential**: Safer for sensitive operations (certificates, operators)
- **Parallel**: Faster for read-only checks (quotas, restarts, OOM events)

## ⚠️ Important Considerations

### 1. Execution Time

**Sequential Mode**:
- Time = (Number of clusters) × (Check duration per cluster)
- Example: 15 clusters × 2 minutes = **30 minutes total**

**Parallel Mode**:
- Time ≈ (Longest cluster check duration)
- Example: 15 clusters checked simultaneously = **~2-3 minutes total**

### 2. Resource Usage

**Parallel Mode** creates multiple simultaneous connections:
- Multiple backplane sessions
- Higher CPU/memory usage on Jenkins agent
- More API calls to OCM

**Recommendation**: Start with **sequential mode** for large accounts (>10 clusters)

### 3. Error Handling

The pipeline is designed to **continue on errors**:
- If one cluster fails, others continue
- Failed clusters are marked as `unstable` but don't fail the whole pipeline
- Check individual stage logs for failures

### 4. Backplane Session Cleanup

Sessions are cleaned up in `post` block:
```groovy
post {
    always {
        sh 'ocm backplane logout || true'
    }
}
```

Even if the pipeline fails, sessions are closed.

## 🧪 Testing

### Test with a Small Account

Before running on large accounts, test with a small one:

```bash
# Find an account with few clusters
ocm list clusters | head -5
ocm describe cluster <cluster-id> | grep AccountNumber

# Use that account number for testing
```

### Dry Run Mode

You can create a dry-run parameter:

```groovy
parameters {
    string(name: 'ACCOUNT_NUMBER', ...)
    booleanParam(name: 'DRY_RUN', defaultValue: true, description: 'Preview clusters without executing checks')
}

// In pipeline:
if (params.DRY_RUN) {
    echo "DRY RUN: Would check ${clusters.size()} clusters"
    clusters.each { echo "  - ${it.name} (${it.id})" }
    return
}
```

## 📝 Example Use Cases

### Use Case 1: Quarterly Account Review

**Scenario**: Review all BP clusters for certificate expiration

```groovy
ACCOUNT_NUMBER: 11800160
CHECK: Jenkinsfile-account-certificates
EXECUTION_MODE: sequential
```

### Use Case 2: Proactive Resource Planning

**Scenario**: Check resource usage across all customer clusters

```groovy
ACCOUNT_NUMBER: 11800160
CHECK: Jenkinsfile-account-resource-consumers
TOP_N: 10
EXECUTION_MODE: parallel
```

### Use Case 3: Pre-Maintenance Health Check

**Scenario**: Verify no degraded operators before maintenance window

```groovy
ACCOUNT_NUMBER: 11800160
CHECK: Jenkinsfile-account-degraded-operators
EXECUTION_MODE: sequential
```

## 🔍 Troubleshooting

### Issue 1: "No clusters found for Account Number"

**Cause**: Invalid account number or no clusters in account

**Solution**:
```bash
# Verify account number
ocm get "/api/accounts_mgmt/v1/organizations?search=ebs_account_id='11800160'"

# Check if organization exists
```

### Issue 2: "Backplane login failed"

**Cause**: Cluster not accessible or in failed state

**Solution**: Pipeline continues with other clusters. Check cluster state:
```bash
ocm describe cluster <cluster-id>
```

### Issue 3: "Pipeline timeout"

**Cause**: Too many clusters in sequential mode

**Solution**:
- Switch to `parallel` mode for read-only checks
- Or increase Jenkins job timeout

### Issue 4: "Out of memory errors"

**Cause**: Too many parallel backplane sessions

**Solution**:
- Switch to `sequential` mode
- Or implement batching (check 5 clusters at a time)

## 🚀 Advanced: Batch Parallel Execution

For very large accounts (>20 clusters), use batched parallel execution:

```groovy
def batchSize = 5
def batches = clusters.collate(batchSize)

batches.each { batch ->
    parallel batch.collectEntries { cluster ->
        ["${cluster.name}": checkClosure(cluster)]
    }
}
```

This checks **5 clusters at a time in parallel**, then moves to the next batch.

## 📚 Related Documentation

- [Main README](README.md) - Overview of all health checks
- [Jenkins Setup Guide](JENKINS_SETUP_GUIDE.md) - Detailed Jenkins configuration
- [Quick Reference](QUICK_REFERENCE.md) - Command reference

## 🤝 Contributing

To add a new account-based check:

1. Copy `Jenkinsfile-account-resource-consumers`
2. Rename to `Jenkinsfile-account-<your-check>`
3. Replace check script in the execution stage
4. Update Service Log title and severity
5. Test with a small account first
6. Create Jenkins job

---

**Questions or Issues?** Check the troubleshooting section or review existing Jenkinsfiles for examples.

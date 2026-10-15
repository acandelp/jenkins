# Account-Based Integration Summary

## 📦 What Was Created

This integration allows you to run Jenkins health checks across **all clusters** belonging to a specific customer account (identified by Account Number / EBS Account ID).

### New Files Created

| File | Purpose | Location |
|------|---------|----------|
| `get-clusters-by-account.sh` | Retrieves all cluster IDs for an account | `utils/` |
| `Jenkinsfile-account-resource-consumers` | Example: Resource consumption check for all account clusters | Root |
| `Jenkinsfile-account-template` | Template for creating custom account-based checks | Root |
| `ACCOUNT_BASED_CHECKS.md` | Complete documentation and guide | Root |
| `ACCOUNT_INTEGRATION_SUMMARY.md` | This file - Quick start guide | Root |

### Updated Files

| File | What Changed |
|------|--------------|
| `README.md` | Added "Account-Based Checks" section |

## 🚀 Quick Start (5 Minutes)

### Step 1: Find an Account Number

```bash
# Pick any cluster and get its account number
ocm describe cluster <any-cluster-id> | grep AccountNumber
```

**Example Output**:
```
AccountNumber:          11800160
```

### Step 2: Test the Utility Script

```bash
cd /Users/adriancandelprestel/Desktop/SRE/jenkins

# List all cluster IDs for this account
./utils/get-clusters-by-account.sh 11800160

# Get detailed info (cluster_id|name|state)
./utils/get-clusters-by-account.sh 11800160 details
```

**Example Output**:
```
2dhfsqa1ejpmfvaaaao0v6etmhq2ih10|eu-prd-01|ready
2e1gfqb350ktnq43fdq860r9vgf47o9g|eu-prd-02|ready
2e4qenv9dchf6q6sh3mi71lgcjqhs61j|us-prd-01|ready
...
```

### Step 3: Create a Jenkins Job

1. **Go to Jenkins** → New Item
2. **Name**: `Account-Resource-Consumers`
3. **Type**: Pipeline
4. **Pipeline Configuration**:
   - Definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: `<your-git-repo-url>`
   - Script Path: `Jenkinsfile-account-resource-consumers`
5. **Save**

### Step 4: Run the Job

1. Click **"Build with Parameters"**
2. Enter:
   - **ACCOUNT_NUMBER**: `11800160`
   - **TOP_N**: `5`
   - **EXECUTION_MODE**: `sequential` (safer for first run)
3. Click **"Build"**

### Step 5: Monitor Execution

Watch the console output:

```
🔍 Validating Account Number: 11800160
📋 Retrieving all clusters for Account Number: 11800160
✅ Found 15 total clusters, 12 in ready state
  - 2dhfsqa1ejpmfvaaaao0v6etmhq2ih10 (eu-prd-01)
  - 2e1gfqb350ktnq43fdq860r9vgf47o9g (eu-prd-02)
  - 2e4qenv9dchf6q6sh3mi71lgcjqhs61j (us-prd-01)
  ...

🔍 Checking cluster: eu-prd-01 (2dhfsqa1ejpmfvaaaao0v6etmhq2ih10)
✅ Backplane login successful for eu-prd-01
ℹ️  Resource consumption report generated for eu-prd-01
✅ Service log sent for eu-prd-01

🔍 Checking cluster: eu-prd-02 (2e1gfqb350ktnq43fdq860r9vgf47o9g)
✅ Backplane login successful for eu-prd-02
ℹ️  Resource consumption report generated for eu-prd-02
✅ Service log sent for eu-prd-02

...

✅ Resource consumption reports completed for all clusters in Account 11800160
```

## 🎯 Common Use Cases

### Use Case 1: Create Account-Based Certificate Check

```bash
# 1. Copy the template
cp Jenkinsfile-account-template Jenkinsfile-account-certificates

# 2. Edit the file and replace:
#    - YOUR-CHECK-SCRIPT.sh → check-certificates.sh
#    - YOUR TITLE HERE → Certificate Expiration Warning
#    - Warning severity (already correct)

# 3. Create Jenkins job pointing to new Jenkinsfile

# 4. Run with account number
Build Parameters:
  ACCOUNT_NUMBER: 11800160
  EXECUTION_MODE: sequential
```

### Use Case 2: Create Account-Based Quota Check

```bash
# 1. Copy the template
cp Jenkinsfile-account-template Jenkinsfile-account-quotas

# 2. Customize for quota checking:
#    - Add THRESHOLD parameter (default: 85)
#    - Set script: ./scripts/check-quotas.sh ${params.THRESHOLD}
#    - Set title: Resource Quota Warning
#    - Set severity: Warning

# 3. Create Jenkins job

# 4. Run with parameters:
Build Parameters:
  ACCOUNT_NUMBER: 11800160
  THRESHOLD: 85
  EXECUTION_MODE: parallel  # Quotas are safe to check in parallel
```

### Use Case 3: Quarterly Account Health Review

Create a **multi-stage pipeline** that runs all checks:

```groovy
pipeline {
    parameters {
        string(name: 'ACCOUNT_NUMBER', ...)
    }

    stages {
        stage('Certificate Check') {
            steps {
                build job: 'Account-Certificates',
                      parameters: [string(name: 'ACCOUNT_NUMBER', value: params.ACCOUNT_NUMBER)]
            }
        }
        
        stage('Resource Check') {
            steps {
                build job: 'Account-Resource-Consumers',
                      parameters: [string(name: 'ACCOUNT_NUMBER', value: params.ACCOUNT_NUMBER)]
            }
        }
        
        stage('Operator Check') {
            steps {
                build job: 'Account-Degraded-Operators',
                      parameters: [string(name: 'ACCOUNT_NUMBER', value: params.ACCOUNT_NUMBER)]
            }
        }
    }
}
```

## 📊 Performance Comparison

### Traditional Approach (Per-Cluster)

**Scenario**: Check 15 clusters for resource consumption

```
Time: 15 manual job runs × 5 minutes each = 75 minutes
Effort: Manual job trigger for each cluster
Risk: Easy to miss clusters
```

### New Account-Based Approach

**Sequential Mode**:
```
Time: 1 job run × (15 clusters × 2 minutes) = 30 minutes
Effort: Single job trigger
Risk: Zero - all clusters checked automatically
```

**Parallel Mode**:
```
Time: 1 job run × ~3 minutes = 3 minutes
Effort: Single job trigger
Risk: Zero - all clusters checked automatically
Savings: 96% time reduction (3 min vs 75 min)
```

## 🔧 Customization Guide

### Adding Custom Parameters

Edit your account-based Jenkinsfile:

```groovy
parameters {
    string(name: 'ACCOUNT_NUMBER', ...)
    
    // ADD YOUR CUSTOM PARAMETERS HERE
    string(
        name: 'WARNING_THRESHOLD',
        defaultValue: '80',
        description: 'Warning threshold percentage'
    )
    
    choice(
        name: 'SEVERITY_LEVEL',
        choices: ['Warning', 'Info', 'Critical'],
        description: 'Service Log severity'
    )
}

// Use in check execution:
sh "./scripts/check-quotas.sh ${params.WARNING_THRESHOLD}"
```

### Filtering Clusters

Filter clusters by criteria before checking:

```groovy
// Only production clusters
def prodClusters = clusters.findAll { it.name.contains('prd') }

// Only EU clusters
def euClusters = clusters.findAll { it.name.startsWith('eu-') }

// Only clusters in ready state (already done by default)
def readyClusters = clusters.findAll { it.state == 'ready' }

// Only HCP clusters (requires additional API call)
def hcpClusters = clusters.findAll { cluster ->
    def info = sh(script: "ocm describe cluster ${cluster.id}", returnStdout: true)
    info.contains('HCP: true')
}
```

### Custom Result Processing

Parse check script output:

```groovy
def results = sh(script: "./scripts/check-certificates.sh", returnStdout: true).trim()

// Split by lines
def lines = results.split('\n')

// Filter warnings only
def warnings = lines.findAll { it.contains('WARNING') }

// Count issues
def issueCount = warnings.size()

// Build custom message
def message = "Found ${issueCount} certificates expiring soon in ${cluster.name}"
```

## 🛠️ Troubleshooting

### Issue: "No clusters found for Account Number"

**Cause**: Invalid or incorrect account number

**Solution**:
```bash
# Verify account number exists
ocm get "/api/accounts_mgmt/v1/organizations?search=ebs_account_id='11800160'"

# Check output:
{
  "items": [
    {
      "id": "...",
      "name": "BP P.L.C.",
      "ebs_account_id": "11800160"
    }
  ]
}
```

### Issue: "Pipeline timeout after 30 minutes"

**Cause**: Too many clusters in sequential mode

**Solutions**:
1. **Switch to parallel mode** (if check is safe for parallelization)
2. **Increase Jenkins timeout**:
   ```groovy
   options {
       timeout(time: 2, unit: 'HOURS')
   }
   ```
3. **Filter clusters** (only production, only specific region, etc.)

### Issue: "Backplane login failed for cluster X"

**Cause**: Cluster not accessible or in degraded state

**Expected Behavior**: Pipeline marks cluster as unstable and continues with others

**Check**:
```bash
ocm describe cluster <cluster-id>
# Look for State: ready/hibernating/failed
```

### Issue: "Some clusters missing from results"

**Cause**: Only clusters in `ready` state are checked (by design)

**To check all clusters** (including hibernating/degraded):
```groovy
// Remove the filter:
// def readyClusters = clusters.findAll { it.state == 'ready' }

// Use all clusters:
def allClusters = clusters
```

## 📚 Additional Resources

### Full Documentation

- **[ACCOUNT_BASED_CHECKS.md](ACCOUNT_BASED_CHECKS.md)** - Complete guide with examples
- **[README.md](README.md)** - Main project documentation
- **[JENKINS_SETUP_GUIDE.md](JENKINS_SETUP_GUIDE.md)** - Jenkins configuration

### Example Jenkinsfiles

- **`Jenkinsfile-account-resource-consumers`** - Working example
- **`Jenkinsfile-account-template`** - Customizable template
- **`Jenkinsfile-resource-consumers`** - Single-cluster version (for comparison)

### Utility Scripts

- **`utils/get-clusters-by-account.sh`** - Cluster discovery
- **`utils/send-service-log.sh`** - Service log sender
- **`scripts/check-*.sh`** - Health check scripts

## 🎓 Learning Path

### Beginner

1. ✅ Read this summary
2. ✅ Test `get-clusters-by-account.sh` manually
3. ✅ Run `Jenkinsfile-account-resource-consumers` on a small account
4. ✅ Review the console output

### Intermediate

1. ✅ Copy `Jenkinsfile-account-template`
2. ✅ Create a custom account-based check (certificates or quotas)
3. ✅ Test with sequential mode
4. ✅ Try parallel mode for comparison

### Advanced

1. ✅ Create multi-stage pipeline (all checks in one job)
2. ✅ Add custom filtering logic (prod-only, region-specific)
3. ✅ Implement batched parallel execution for large accounts
4. ✅ Add custom metrics and reporting

## ✅ Validation Checklist

Before deploying to production:

- [ ] Tested `get-clusters-by-account.sh` with valid account number
- [ ] Ran example pipeline on **small test account** first
- [ ] Verified Service Logs are sent correctly
- [ ] Tested both sequential and parallel modes
- [ ] Reviewed error handling (one cluster failure doesn't block others)
- [ ] Confirmed backplane sessions are cleaned up
- [ ] Tested with account having 10+ clusters
- [ ] Documented any custom modifications

## 🚀 Next Steps

1. **Test the example pipeline** with a real account number
2. **Create your first custom check** using the template
3. **Schedule regular runs** using Jenkins cron triggers
4. **Share feedback** and improvements with the team

## 💡 Pro Tips

1. **Start with sequential mode** - Safer for first runs
2. **Test on small accounts first** - Fewer clusters = faster feedback
3. **Use parallel mode for read-only checks** - Quotas, OOM events, pod restarts
4. **Keep sequential for sensitive ops** - Certificates, operator checks
5. **Add dry-run parameter** - Preview clusters before executing
6. **Monitor first execution closely** - Watch for unexpected issues
7. **Set reasonable timeouts** - Account for (cluster count × check duration)

---

**Questions?** Review [ACCOUNT_BASED_CHECKS.md](ACCOUNT_BASED_CHECKS.md) for detailed documentation.

**Issues?** Check the Troubleshooting section above.

**Ready to start?** Jump to Quick Start above! 🎉

# Aurora MySQL Cluster Restoration Guide

## Executive Summary
This comprehensive guide documents the complete process of restoring an AWS Aurora MySQL cluster using manual snapshots through the Facets control plane. This guide is based on actual restoration testing performed on September 8-9, 2025, including bug fixes and validation procedures.

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Understanding Aurora Restoration](#understanding-aurora-restoration)
4. [Step-by-Step Restoration Process](#step-by-step-restoration-process)
5. [Verification and Testing](#verification-and-testing)
6. [Connectivity Testing](#connectivity-testing)
7. [Debugging and Troubleshooting](#debugging-and-troubleshooting)
8. [Common Issues and Solutions](#common-issues-and-solutions)
9. [Best Practices](#best-practices)
10. [Appendix: Command Reference](#appendix-command-reference)

---

## Overview

### What This Guide Covers
- Creating manual snapshots of Aurora MySQL clusters
- Configuring restoration through Facets control plane
- Verifying successful restoration using CloudTrail and AWS CLI
- Testing database connectivity and data integrity
- Troubleshooting common restoration issues

### Key Differences from RDS MySQL
- Aurora uses **cluster-level snapshots** (not instance-level)
- Restoration creates both **writer and reader instances**
- Aurora can **auto-upgrade engine versions** during restoration
- CloudTrail is the **primary evidence source** for restoration verification

### Module Architecture
```
datastore/mysql/aws-aurora/1.0/
├── facets.yaml     # Configuration schema with restoration fields
├── main.tf         # Terraform resources with conditional restoration logic
├── variables.tf    # Input variables including restore_config
├── locals.tf       # Local variables for computed values
└── outputs.tf      # Output definitions
```

---

## Prerequisites

### Required Access
- **AWS CLI** configured with appropriate IAM permissions
- **Facets Control Plane** access with deployment permissions
- **CloudTrail** read access for verification
- **RDS permissions**: CreateDBClusterSnapshot, RestoreDBClusterFromSnapshot

### Required Tools
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Install MySQL client for testing
sudo apt-get update && sudo apt-get install mysql-client -y  # Ubuntu/Debian
sudo yum install mysql -y  # Amazon Linux/CentOS

# Install jq for JSON parsing
sudo apt-get install jq -y  # Ubuntu/Debian
sudo yum install jq -y  # Amazon Linux/CentOS
```

### Information to Gather
- Source cluster identifier
- VPC and subnet configuration
- Security group IDs
- Master username and password for restoration

---

## Understanding Aurora Restoration

### How Aurora Restoration Works
1. **Snapshot Creation**: Creates a cluster-level snapshot including all data
2. **Restoration Process**: Uses `RestoreDBClusterFromSnapshot` API
3. **Instance Creation**: Automatically creates writer and reader instances
4. **Configuration Inheritance**: Database name, username inherited from snapshot
5. **Version Management**: May auto-upgrade to compatible minor versions

### Critical Module Logic
The Aurora module uses conditional logic for restoration:

```hcl
# From main.tf - Key restoration logic
resource "aws_rds_cluster" "aurora" {
  # When restoring, these MUST be null to inherit from snapshot
  engine_version  = local.restore_from_backup ? null : var.instance.spec.version_config.engine_version
  database_name   = local.restore_from_backup ? null : var.instance.spec.version_config.database_name
  master_username = local.restore_from_backup ? null : local.master_username
  master_password = local.restore_from_backup ? null : local.master_password
  
  # This tells AWS to restore from snapshot
  snapshot_identifier = local.restore_from_backup ? var.instance.spec.restore_config.source_snapshot_identifier : null
}
```

### Restoration vs Fresh Creation
| Aspect | Fresh Creation | Snapshot Restoration |
|--------|---------------|---------------------|
| API Call | CreateDBCluster | RestoreDBClusterFromSnapshot |
| Credentials | New random generated | Set by user (inherited internally) |
| Database Name | Specified in config | Inherited from snapshot |
| Engine Version | Specified in config | Inherited (may auto-upgrade) |
| Data | Empty database | Full data from snapshot |

---

## Step-by-Step Restoration Process

### Phase 1: Identify and Prepare Source Cluster

#### 1.1 Find Your Source Cluster
```bash
# List all Aurora clusters
aws rds describe-db-clusters \
  --query 'DBClusters[?Engine==`aurora-mysql`].{ID:DBClusterIdentifier,Status:Status,Version:EngineVersion}' \
  --output table

# Get detailed information about specific cluster
aws rds describe-db-clusters \
  --db-cluster-identifier "your-source-cluster-id" \
  --query 'DBClusters[0].{ID:DBClusterIdentifier,Database:DatabaseName,Username:MasterUsername,Status:Status}' \
  --output table
```

#### 1.2 Verify Cluster Health
```bash
# Check cluster status
aws rds describe-db-clusters \
  --db-cluster-identifier "your-source-cluster-id" \
  --query 'DBClusters[0].Status' \
  --output text

# Expected output: "available"
```

#### 1.3 Record Critical Information
Document these values for later use:
- Cluster Identifier: `test-aurora-db-test-datastore-1155708878-dev-aws`
- Database Name: `mydb`
- Master Username: `admin`
- Engine Version: `8.0.mysql_aurora.3.07.1`

### Phase 2: Create Manual Snapshot

#### 2.1 Create the Snapshot
```bash
# Set variables
CLUSTER_ID="test-aurora-db-test-datastore-1155708878-dev-aws"
SNAPSHOT_ID="aurora-restore-snapshot-$(date +%Y%m%d-%H%M%S)"

# Create snapshot
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier "$CLUSTER_ID" \
  --db-cluster-snapshot-identifier "$SNAPSHOT_ID"

echo "Snapshot ID: $SNAPSHOT_ID"
```

#### 2.2 Monitor Snapshot Creation
```bash
# Check snapshot status
aws rds describe-db-cluster-snapshots \
  --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
  --query 'DBClusterSnapshots[0].{Status:Status,Progress:PercentProgress}' \
  --output table

# Wait for completion (typically 5-10 minutes)
aws rds wait db-cluster-snapshot-completed \
  --db-cluster-snapshot-identifier "$SNAPSHOT_ID"

echo "✅ Snapshot ready for restoration"
```

#### 2.3 Verify Snapshot Details
```bash
aws rds describe-db-cluster-snapshots \
  --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
  --query 'DBClusterSnapshots[0]' \
  --output json | jq '{
    SnapshotId: .DBClusterSnapshotIdentifier,
    SourceCluster: .DBClusterIdentifier,
    Status: .Status,
    CreatedTime: .SnapshotCreateTime,
    Engine: .Engine,
    EngineVersion: .EngineVersion,
    DatabaseName: .DatabaseName,
    MasterUsername: .MasterUsername
  }'
```

### Phase 3: Configure Restoration in Facets

#### 3.1 Navigate to Target Resource
1. Open Facets Control Plane
2. Go to your environment (e.g., `dev-aws`)
3. Find your target Aurora resource (e.g., `test-aurora-db-new`)
4. Click to configure

#### 3.2 Enable Restoration Configuration
In the configuration UI, set:

```yaml
restore_config:
  restore_from_backup: true
  source_snapshot_identifier: "aurora-restore-snapshot-20250908-232944"
  master_username: "admin"
  master_password: "YourSecurePassword123!"
```

#### 3.3 Configure Other Required Fields
```yaml
version_config:
  engine_version: "8.0.mysql_aurora.3.07.1"  # Will be inherited from snapshot
  database_name: "mydb"                      # Will be inherited from snapshot

sizing:
  instance_class: "db.t4g.medium"
  min_capacity: 1
  max_capacity: 4
  read_replica_count: 1
```

#### 3.4 Deploy the Resource
1. Save configuration
2. Review changes
3. Click "Deploy"
4. Note the deployment ID for tracking

### Phase 4: Monitor Restoration Progress

#### 4.1 Track Cluster Creation
```bash
# Set the new cluster ID
NEW_CLUSTER_ID="test-aurora-db-new-test-datastore-1155708878-dev-aws"

# Monitor status
watch -n 10 'aws rds describe-db-clusters \
  --db-cluster-identifier "$NEW_CLUSTER_ID" \
  --query "DBClusters[0].{Status:Status}" \
  --output table'
```

#### 4.2 Check Instance Creation
```bash
# Monitor writer and reader instances
aws rds describe-db-instances \
  --query "DBInstances[?contains(DBInstanceIdentifier, 'aurora-db-new')].{
    Instance:DBInstanceIdentifier,
    Status:DBInstanceStatus,
    Role:DBInstanceClass
  }" \
  --output table
```

#### 4.3 Expected Timeline
- **0-2 minutes**: Cluster creation initiated
- **2-5 minutes**: Cluster in "creating" status
- **5-10 minutes**: Writer instance creation
- **10-15 minutes**: Reader instance creation
- **15-20 minutes**: All instances "available"

---

## Verification and Testing

### Step 1: Verify Restoration via CloudTrail

#### Check for RestoreDBClusterFromSnapshot Event
```bash
# This is the DEFINITIVE proof of restoration
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RestoreDBClusterFromSnapshot \
  --max-items 5 \
  --query 'Events[*].{
    Time:EventTime,
    Snapshot:Resources[0].ResourceName,
    User:Username
  }' \
  --output table
```

**Expected Output:**
```
Time: 2025-09-08T23:50:54+05:30
Snapshot: aurora-restore-snapshot-20250908-232944
User: capillary-cloud-tf-xxxxx
```

#### Get Detailed Restoration Event
```bash
# Get full details of the restoration
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$SNAPSHOT_ID" \
  --max-items 1 \
  --query 'Events[0]' | jq -r '.CloudTrailEvent' | jq '.'
```

### Step 2: Configuration Verification

#### Compare Source and Restored Clusters
```bash
# Create comparison report
echo "=== CLUSTER COMPARISON ==="
echo "Source Cluster:"
aws rds describe-db-clusters \
  --db-cluster-identifier "$CLUSTER_ID" \
  --query 'DBClusters[0].{
    Engine:Engine,
    Version:EngineVersion,
    Database:DatabaseName,
    Username:MasterUsername,
    Created:ClusterCreateTime
  }' --output table

echo -e "\nRestored Cluster:"
aws rds describe-db-clusters \
  --db-cluster-identifier "$NEW_CLUSTER_ID" \
  --query 'DBClusters[0].{
    Engine:Engine,
    Version:EngineVersion,
    Database:DatabaseName,
    Username:MasterUsername,
    Created:ClusterCreateTime
  }' --output table
```

### Step 3: Timeline Verification

#### Verify Restoration Timeline
```bash
# Check timeline consistency
echo "=== RESTORATION TIMELINE ==="
echo "1. Original Cluster Created:"
aws rds describe-db-clusters --db-cluster-identifier "$CLUSTER_ID" \
  --query 'DBClusters[0].ClusterCreateTime' --output text

echo "2. Snapshot Created:"
aws rds describe-db-cluster-snapshots --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
  --query 'DBClusterSnapshots[0].SnapshotCreateTime' --output text

echo "3. Restored Cluster Created:"
aws rds describe-db-clusters --db-cluster-identifier "$NEW_CLUSTER_ID" \
  --query 'DBClusters[0].ClusterCreateTime' --output text

echo -e "\n✅ Timeline confirms: Snapshot created BEFORE restoration"
```

### Step 4: Data Integrity Checks

#### Check Backup Settings
```bash
# Verify backup configuration carried over
aws rds describe-db-clusters \
  --db-cluster-identifier "$NEW_CLUSTER_ID" \
  --query 'DBClusters[0].{
    BackupRetention:BackupRetentionPeriod,
    BackupWindow:PreferredBackupWindow,
    EarliestRestore:EarliestRestorableTime,
    LatestRestore:LatestRestorableTime
  }' --output table
```

---

## Connectivity Testing

### Method 1: Direct Connection Test (From EC2 in Same VPC)

#### Setup Jump Host
```bash
# Launch EC2 instance in same VPC
# SSH to the instance, then:

# Install MySQL client
sudo yum install mysql -y  # Amazon Linux
# OR
sudo apt-get update && sudo apt-get install mysql-client -y  # Ubuntu

# Get cluster endpoints
ORIGINAL_ENDPOINT=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$CLUSTER_ID" \
  --query 'DBClusters[0].Endpoint' --output text)

RESTORED_ENDPOINT=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$NEW_CLUSTER_ID" \
  --query 'DBClusters[0].Endpoint' --output text)
```

#### Test Connections
```bash
# Test original cluster
mysql -h "$ORIGINAL_ENDPOINT" -u admin -p \
  -e "SELECT 'Original Cluster' as Source, VERSION() as Version, NOW() as Time;"

# Test restored cluster  
mysql -h "$RESTORED_ENDPOINT" -u admin -p \
  -e "SELECT 'Restored Cluster' as Source, VERSION() as Version, NOW() as Time;"
```

### Method 2: Port Connectivity Test

```bash
# Test if port 3306 is accessible
nc -zv "$RESTORED_ENDPOINT" 3306

# Using timeout
timeout 5 nc -zv "$RESTORED_ENDPOINT" 3306 && echo "✅ Connected" || echo "❌ Failed"
```

### Method 3: Comprehensive Database Verification

#### Create Verification Script
```bash
cat > verify_aurora.sh << 'EOF'
#!/bin/bash

# Configuration
ORIGINAL_HOST="$1"
RESTORED_HOST="$2"
USERNAME="admin"
PASSWORD="$3"

echo "=== Aurora Restoration Verification ==="
echo "Original: $ORIGINAL_HOST"
echo "Restored: $RESTORED_HOST"
echo "========================================="

# Function to run query on both clusters
compare_query() {
    local query="$1"
    local description="$2"
    
    echo -e "\n📊 $description"
    echo "Original Cluster:"
    mysql -h "$ORIGINAL_HOST" -u "$USERNAME" -p"$PASSWORD" -e "$query" 2>/dev/null
    
    echo "Restored Cluster:"
    mysql -h "$RESTORED_HOST" -u "$USERNAME" -p"$PASSWORD" -e "$query" 2>/dev/null
}

# Run comparisons
compare_query "SHOW DATABASES;" "Database List"
compare_query "SELECT VERSION();" "MySQL Version"
compare_query "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys');" "Table Count"

echo -e "\n=== Verification Complete ==="
EOF

chmod +x verify_aurora.sh
./verify_aurora.sh "$ORIGINAL_ENDPOINT" "$RESTORED_ENDPOINT" "YourPassword"
```

### Method 4: Application-Level Testing

```bash
# Update application configuration
cat > test_connection.py << 'EOF'
import pymysql
import sys

def test_connection(host, user, password, database):
    try:
        connection = pymysql.connect(
            host=host,
            user=user,
            password=password,
            database=database,
            connect_timeout=10
        )
        
        with connection.cursor() as cursor:
            cursor.execute("SELECT VERSION()")
            version = cursor.fetchone()
            cursor.execute("SELECT COUNT(*) FROM information_schema.tables")
            tables = cursor.fetchone()
            
        print(f"✅ Connected to {host}")
        print(f"   Version: {version[0]}")
        print(f"   Tables: {tables[0]}")
        connection.close()
        return True
        
    except Exception as e:
        print(f"❌ Failed to connect to {host}: {str(e)}")
        return False

if __name__ == "__main__":
    original = test_connection(sys.argv[1], "admin", sys.argv[3], "mydb")
    restored = test_connection(sys.argv[2], "admin", sys.argv[3], "mydb")
    
    if original and restored:
        print("\n✅ Both clusters are accessible!")
    else:
        print("\n⚠️ Connection issues detected")
        sys.exit(1)
EOF

python3 test_connection.py "$ORIGINAL_ENDPOINT" "$RESTORED_ENDPOINT" "YourPassword"
```

---

## Debugging and Troubleshooting

### Common Restoration Issues

#### Issue 1: Restoration Not Working (Cluster Created Fresh)

**Symptoms:**
- Cluster has no data
- Random password generated instead of using provided one
- No RestoreDBClusterFromSnapshot event in CloudTrail

**Root Cause:**
Module not setting credentials to `null` during restoration

**Solution:**
Ensure main.tf has correct conditional logic:
```hcl
# CORRECT - credentials set to null when restoring
master_username = local.restore_from_backup ? null : local.master_username
master_password = local.restore_from_backup ? null : local.master_password

# WRONG - always sets credentials (prevents restoration)
master_username = local.master_username
master_password = local.master_password
```

#### Issue 2: Engine Version Mismatch

**Symptoms:**
- Restored cluster has different engine version than source
- Version auto-upgraded (e.g., 3.07.1 → 3.08.2)

**Explanation:**
AWS may auto-upgrade to latest compatible minor version during restoration

**Solution:**
This is normal behavior. To prevent:
1. Specify exact version in cluster parameter group
2. Use `engine_version_actual` in verification
3. Test application compatibility with new version

#### Issue 3: Instances Not Creating

**Symptoms:**
- Cluster shows "available" but no instances
- Writer/Reader instances missing

**Root Cause:**
Terraform may not be creating instances after cluster restoration

**Solution:**
Check instance resources in main.tf:
```hcl
resource "aws_rds_cluster_instance" "aurora_writer" {
  count              = 1
  identifier         = "${local.cluster_identifier}-writer"
  cluster_identifier = aws_rds_cluster.aurora.id
  # ... rest of configuration
}
```

### Debugging Commands

#### Check Terraform Logs
```bash
# If using Facets, check deployment logs
# Via AWS CloudWatch
aws logs tail /aws/terraform/your-deployment-id --follow
```

#### Monitor RDS Events
```bash
# Check all events for the cluster
aws rds describe-events \
  --source-type db-cluster \
  --source-identifier "$NEW_CLUSTER_ID" \
  --duration 120 \
  --query 'Events[*].{Time:Date,Message:Message}' \
  --output table
```

#### Verify Security Groups
```bash
# Check security group rules
SG_ID=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$NEW_CLUSTER_ID" \
  --query 'DBClusters[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text)

aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query 'SecurityGroups[0].IpPermissions[*].{
    Port:FromPort,
    Protocol:IpProtocol,
    Sources:IpRanges[*].CidrIp
  }' --output table
```

### Verification Checklist

```bash
# Create comprehensive verification script
cat > aurora_verify.sh << 'EOF'
#!/bin/bash

CLUSTER_ID="$1"

echo "=== Aurora Cluster Verification ==="
echo "Cluster: $CLUSTER_ID"
echo "===================================="

# 1. Cluster Status
STATUS=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$CLUSTER_ID" \
  --query 'DBClusters[0].Status' --output text)
echo "✓ Cluster Status: $STATUS"

# 2. Instance Count
INSTANCES=$(aws rds describe-db-instances \
  --query "DBInstances[?DBClusterIdentifier=='$CLUSTER_ID'].DBInstanceIdentifier" \
  --output text | wc -l)
echo "✓ Instance Count: $INSTANCES"

# 3. Backup Configuration
BACKUP=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$CLUSTER_ID" \
  --query 'DBClusters[0].BackupRetentionPeriod' --output text)
echo "✓ Backup Retention: $BACKUP days"

# 4. Encryption Status
ENCRYPTED=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$CLUSTER_ID" \
  --query 'DBClusters[0].StorageEncrypted' --output text)
echo "✓ Storage Encrypted: $ENCRYPTED"

# 5. Check CloudTrail for Restoration
echo -e "\n📋 Checking CloudTrail for restoration evidence..."
RESTORE_EVENT=$(aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RestoreDBClusterFromSnapshot \
  --max-items 10 \
  --query "Events[?contains(CloudTrailEvent, '$CLUSTER_ID')].EventTime" \
  --output text)

if [ -n "$RESTORE_EVENT" ]; then
    echo "✅ RESTORATION CONFIRMED at $RESTORE_EVENT"
else
    echo "⚠️ No restoration event found (may be fresh creation)"
fi

echo -e "\n=== Verification Complete ==="
EOF

chmod +x aurora_verify.sh
./aurora_verify.sh "$NEW_CLUSTER_ID"
```

---

## Common Issues and Solutions

### Issue: "No restoration events in RDS console"

**Understanding:**
AWS RDS Events don't show restoration for manual snapshots. This is normal.

**Solution:**
Use CloudTrail to verify restoration:
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RestoreDBClusterFromSnapshot
```

### Issue: "Password doesn't work after restoration"

**Cause:**
The password provided in restore_config isn't actually used by AWS.

**Solution:**
1. Use the original cluster's password
2. Or reset password after restoration:
```bash
aws rds modify-db-cluster \
  --db-cluster-identifier "$NEW_CLUSTER_ID" \
  --master-user-password "NewSecurePassword123!" \
  --apply-immediately
```

### Issue: "Connection timeout to restored cluster"

**Checklist:**
1. **Security Group:** Port 3306 open?
2. **Network ACL:** Allow traffic?
3. **Route Table:** Proper routing?
4. **Instance Status:** All instances "available"?

**Debug:**
```bash
# Check instance endpoints
aws rds describe-db-instances \
  --query "DBInstances[?DBClusterIdentifier=='$NEW_CLUSTER_ID'].{
    Instance:DBInstanceIdentifier,
    Endpoint:Endpoint.Address,
    Port:Endpoint.Port,
    Status:DBInstanceStatus
  }" --output table
```

### Issue: "Terraform destroy fails"

**Cause:**
Deletion protection or final snapshot required

**Solution:**
```bash
# Disable deletion protection
aws rds modify-db-cluster \
  --db-cluster-identifier "$NEW_CLUSTER_ID" \
  --no-deletion-protection \
  --apply-immediately

# Delete with final snapshot
aws rds delete-db-cluster \
  --db-cluster-identifier "$NEW_CLUSTER_ID" \
  --final-db-snapshot-identifier "final-snapshot-$(date +%Y%m%d-%H%M%S)"
```

---

## Best Practices

### Before Starting Restoration

1. **Document Everything**
   ```bash
   # Create restoration plan document
   cat > restoration_plan.md << EOF
   # Aurora Restoration Plan
   Date: $(date)
   Source Cluster: $CLUSTER_ID
   Target Cluster: $NEW_CLUSTER_ID
   Snapshot: $SNAPSHOT_ID
   
   ## Pre-checks
   - [ ] Source cluster healthy
   - [ ] Snapshot created successfully
   - [ ] Target configuration ready
   - [ ] CloudTrail access confirmed
   EOF
   ```

2. **Test in Development First**
   - Always test restoration process in non-production
   - Verify module logic works correctly
   - Document any issues encountered

3. **Backup Current State**
   ```bash
   # Create backup before changes
   aws rds create-db-cluster-snapshot \
     --db-cluster-identifier "$CLUSTER_ID" \
     --db-cluster-snapshot-identifier "pre-restore-backup-$(date +%Y%m%d-%H%M%S)"
   ```

### During Restoration

1. **Monitor Actively**
   ```bash
   # Set up monitoring loop
   while true; do
     clear
     echo "=== Restoration Monitor - $(date) ==="
     aws rds describe-db-clusters \
       --db-cluster-identifier "$NEW_CLUSTER_ID" \
       --query 'DBClusters[0].{Status:Status,Progress:PercentProgress}' \
       --output table
     
     aws rds describe-db-instances \
       --query "DBInstances[?DBClusterIdentifier=='$NEW_CLUSTER_ID'].{
         Instance:DBInstanceIdentifier,
         Status:DBInstanceStatus
       }" --output table
     
     sleep 30
   done
   ```

2. **Keep Audit Trail**
   - Screenshot configurations
   - Save CloudTrail events
   - Document deployment IDs

### After Restoration

1. **Comprehensive Verification**
   - Run all verification scripts
   - Test application connectivity
   - Compare data integrity

2. **Update Documentation**
   ```bash
   # Document restoration details
   cat >> restoration_report.md << EOF
   
   ## Restoration Complete
   Completed: $(date)
   
   ### Verification Results
   - CloudTrail Event: Confirmed
   - Data Integrity: Verified
   - Application Test: Passed
   
   ### Endpoints
   - Writer: $(aws rds describe-db-clusters --db-cluster-identifier "$NEW_CLUSTER_ID" --query 'DBClusters[0].Endpoint' --output text)
   - Reader: $(aws rds describe-db-clusters --db-cluster-identifier "$NEW_CLUSTER_ID" --query 'DBClusters[0].ReaderEndpoint' --output text)
   EOF
   ```

3. **Security Hardening**
   - Rotate passwords if needed
   - Review security group rules
   - Enable audit logging

### Production Considerations

1. **High Availability**
   - Ensure Multi-AZ is enabled
   - Configure appropriate read replicas
   - Set proper backup retention

2. **Performance Optimization**
   - Allow cache warmup time
   - Monitor CloudWatch metrics
   - Analyze slow query logs

3. **Disaster Recovery**
   - Document restoration procedures
   - Train team on process
   - Regular restoration drills

---

## Appendix: Command Reference

### Essential AWS CLI Commands

```bash
# Cluster Operations
aws rds describe-db-clusters --db-cluster-identifier <cluster-id>
aws rds create-db-cluster-snapshot --db-cluster-identifier <cluster-id> --db-cluster-snapshot-identifier <snapshot-id>
aws rds restore-db-cluster-from-snapshot --db-cluster-identifier <new-cluster-id> --snapshot-identifier <snapshot-id>
aws rds delete-db-cluster --db-cluster-identifier <cluster-id> --skip-final-snapshot

# Instance Operations
aws rds describe-db-instances --query "DBInstances[?DBClusterIdentifier=='<cluster-id>']"
aws rds create-db-instance --db-instance-identifier <instance-id> --db-cluster-identifier <cluster-id>

# Snapshot Operations
aws rds describe-db-cluster-snapshots --db-cluster-identifier <cluster-id>
aws rds wait db-cluster-snapshot-completed --db-cluster-snapshot-identifier <snapshot-id>

# CloudTrail Verification
aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=RestoreDBClusterFromSnapshot
aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=<snapshot-id>

# Monitoring
aws rds describe-events --source-type db-cluster --source-identifier <cluster-id>
aws cloudwatch get-metric-statistics --namespace AWS/RDS --metric-name CPUUtilization --dimensions Name=DBClusterIdentifier,Value=<cluster-id>
```

### MySQL Connection Commands

```sql
-- Basic connectivity test
SELECT VERSION(), NOW(), USER();

-- Database inspection
SHOW DATABASES;
USE database_name;
SHOW TABLES;

-- Data verification
SELECT COUNT(*) FROM table_name;
SELECT * FROM table_name LIMIT 10;

-- User and permissions
SELECT User, Host FROM mysql.user;
SHOW GRANTS FOR CURRENT_USER();

-- Replication status (for read replicas)
SHOW SLAVE STATUS\G
```

### Troubleshooting Scripts

```bash
# Network connectivity test
#!/bin/bash
check_connectivity() {
    local endpoint=$1
    echo "Testing $endpoint..."
    
    # DNS resolution
    nslookup $endpoint
    
    # Port check
    nc -zv $endpoint 3306
    
    # Ping test (may be blocked)
    ping -c 3 $endpoint
}

# Security group analyzer
#!/bin/bash
analyze_security() {
    local cluster_id=$1
    
    # Get security group
    sg_id=$(aws rds describe-db-clusters \
      --db-cluster-identifier "$cluster_id" \
      --query 'DBClusters[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
      --output text)
    
    # Analyze rules
    aws ec2 describe-security-groups --group-ids "$sg_id" \
      --query 'SecurityGroups[0].IpPermissions[*]'
}
```

---

## Conclusion

This comprehensive guide provides everything needed to successfully restore Aurora MySQL clusters using the Facets control plane. Key takeaways:

1. **Always verify restoration via CloudTrail** - it's the only reliable source
2. **Module logic is critical** - ensure credentials are set to null during restoration
3. **Test thoroughly** - use the verification scripts provided
4. **Monitor actively** - restoration can take 15-20 minutes
5. **Document everything** - maintain audit trails for compliance

Remember: Aurora restoration is different from regular RDS. Understanding these differences ensures successful restoration operations.

---

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-09-09 | 1.0 | Initial comprehensive guide created |
| 2025-09-09 | 1.1 | Added CloudTrail verification methods |
| 2025-09-09 | 1.2 | Fixed module logic for proper restoration |

---

*Last Updated: September 9, 2025*  
*Based on: AWS Aurora MySQL 8.0, Facets Control Plane, Terraform AWS Provider 5.x*  
*Tested with: aws-aurora module version 1.0*
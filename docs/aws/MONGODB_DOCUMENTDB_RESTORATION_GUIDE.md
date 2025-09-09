# MongoDB DocumentDB Restoration Guide

## Overview
This comprehensive guide provides detailed instructions for restoring AWS DocumentDB (MongoDB-compatible) clusters using snapshots through the Facets control plane. DocumentDB restoration creates a new cluster from a snapshot, preserving all data and allowing for disaster recovery or cloning scenarios.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Understanding DocumentDB Restoration](#understanding-documentdb-restoration)
3. [Step-by-Step Restoration Process](#step-by-step-restoration-process)
4. [Verification and Testing](#verification-and-testing)
5. [Connectivity Testing](#connectivity-testing)
6. [Debugging and Troubleshooting](#debugging-and-troubleshooting)
7. [Best Practices and Security](#best-practices-and-security)
8. [Common Issues and Solutions](#common-issues-and-solutions)

---

## Prerequisites

### Required Access and Permissions
- AWS CLI configured with appropriate IAM permissions:
  - `docdb:CreateDBClusterSnapshot`
  - `docdb:RestoreDBClusterFromSnapshot`
  - `docdb:DescribeDBClusters`
  - `docdb:DescribeDBClusterSnapshots`
  - `cloudtrail:LookupEvents` (for verification)
- Access to Facets control plane
- DocumentDB cluster management permissions

### Required Information
- Source DocumentDB cluster identifier
- Master username and password for restored cluster
- VPC and subnet group details
- Security group configurations

### Tools Needed
```bash
# Install AWS CLI (if not installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install MongoDB Shell (for connectivity testing)
# For macOS:
brew install mongosh

# For Linux:
wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list
sudo apt-get update
sudo apt-get install -y mongodb-mongosh

# Install jq for JSON parsing
sudo apt-get install jq  # Linux
brew install jq          # macOS
```

---

## Understanding DocumentDB Restoration

### How DocumentDB Restoration Works

DocumentDB restoration differs from RDS in that it uses **snapshot-based restoration** rather than point-in-time restore:

1. **Manual Snapshots**: Creates a new cluster from a manually created snapshot
2. **Complete Data Preservation**: All collections, indexes, and users are preserved
3. **New Cluster Creation**: Creates entirely new cluster with new endpoints
4. **Configuration Flexibility**: Can modify instance types and counts during restore

### Key Module Components

```
datastore/mongo-aws-documentdb/
├── facets.yaml     # Configuration schema with restore_config
├── main.tf         # Terraform resources including restore logic
├── locals.tf       # Local variables for connection strings
├── variables.tf    # Input variables with validation
└── outputs.tf      # Output definitions for connections
```

### Restoration Logic in Terraform

```hcl
# From main.tf (line 78)
resource "aws_docdb_cluster" "main" {
  # ... other configurations ...
  
  # Restoration from snapshot
  snapshot_identifier = var.instance.spec.restore_config.restore_from_snapshot ? 
                       var.instance.spec.restore_config.snapshot_identifier : null
  
  # New credentials for restored cluster
  master_username = var.instance.spec.restore_config.restore_from_snapshot ? 
                   var.instance.spec.restore_config.master_username : "docdbadmin"
  master_password = var.instance.spec.restore_config.restore_from_snapshot ? 
                   var.instance.spec.restore_config.master_password : 
                   random_password.master[0].result
}
```

---

## Step-by-Step Restoration Process

### Phase 1: Assess Source DocumentDB Cluster

#### 1.1 List Existing DocumentDB Clusters
```bash
# List all DocumentDB clusters
aws docdb describe-db-clusters \
  --query 'DBClusters[*].[DBClusterIdentifier,Status,Engine,EngineVersion]' \
  --output table

# Get specific cluster details
aws docdb describe-db-clusters \
  --db-cluster-identifier "your-source-cluster" \
  --output json | jq '{
    ClusterIdentifier: .DBClusters[0].DBClusterIdentifier,
    Status: .DBClusters[0].Status,
    Engine: .DBClusters[0].Engine,
    EngineVersion: .DBClusters[0].EngineVersion,
    MasterUsername: .DBClusters[0].MasterUsername,
    Port: .DBClusters[0].Port,
    SubnetGroup: .DBClusters[0].DBSubnetGroup,
    SecurityGroups: .DBClusters[0].VpcSecurityGroups
  }'
```

#### 1.2 Document Cluster Configuration
```bash
# Save cluster configuration for reference
CLUSTER_ID="test-mongo-test-datastore-1155708878-dev-aws"

aws docdb describe-db-clusters \
  --db-cluster-identifier "$CLUSTER_ID" \
  --output json > source_cluster_config.json

echo "Source cluster configuration saved to source_cluster_config.json"
```

### Phase 2: Create Snapshot

#### 2.1 Create Manual Snapshot
```bash
# Generate unique snapshot ID with timestamp
SNAPSHOT_ID="$(echo $CLUSTER_ID | cut -d'-' -f1-2)-restore-$(date +%Y%m%d-%H%M%S)"

echo "Creating snapshot: $SNAPSHOT_ID"

# Create the snapshot
aws docdb create-db-cluster-snapshot \
  --db-cluster-identifier "$CLUSTER_ID" \
  --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
  --output json
```

#### 2.2 Monitor Snapshot Creation
```bash
# Wait for snapshot completion (with progress monitoring)
while true; do 
  STATUS=$(aws docdb describe-db-cluster-snapshots \
    --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
    --query 'DBClusterSnapshots[0].Status' \
    --output text)
  
  PROGRESS=$(aws docdb describe-db-cluster-snapshots \
    --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
    --query 'DBClusterSnapshots[0].PercentProgress' \
    --output text)
  
  echo "Snapshot Status: $STATUS, Progress: $PROGRESS%"
  
  if [ "$STATUS" = "available" ]; then
    echo "✅ Snapshot completed successfully!"
    break
  elif [ "$STATUS" = "failed" ]; then
    echo "❌ Snapshot failed!"
    exit 1
  fi
  
  sleep 10
done
```

### Phase 3: Configure Restoration in Facets Control Plane

#### 3.1 Navigate to Target Resource
1. Access Facets control plane
2. Navigate to your environment (e.g., `dev-aws`)
3. Find or create your target resource (e.g., `test-mongo-new`)

#### 3.2 Configure Restore Settings

In the **Restore Operations** section, configure:

```yaml
Restore Configuration:
  ✅ Restore from Snapshot: true
  Snapshot Identifier: [your-snapshot-id]
  Master Username: docdbadmin
  Master Password: [secure-password-min-8-chars]

# Example values:
  Snapshot Identifier: test-mongo-restore-snapshot-20250908-195008
  Master Username: docdbadmin
  Master Password: RestorePass123!
```

#### 3.3 Maintain Original Configuration
Ensure these match the source cluster:
```yaml
Version & Basic Configuration:
  Engine Version: 5.0.0  # Match source version
  Port: 27017

Sizing & Performance:
  Instance Class: db.t4g.medium  # Can be modified if needed
  Instance Count: 1               # Can be scaled as needed
```

### Phase 4: Deploy and Monitor

#### 4.1 Deploy Through Control Plane
1. Click **Save** to save configuration
2. Click **Deploy** to initiate restoration
3. Monitor deployment status in control plane

#### 4.2 Monitor Restoration Progress
```bash
# Set the new cluster identifier
NEW_CLUSTER_ID="test-mongo-new-test-datastore-1155708878-dev-aws"

# Monitor cluster creation
watch -n 10 'aws docdb describe-db-clusters \
  --db-cluster-identifier "'$NEW_CLUSTER_ID'" \
  --query "DBClusters[0].[DBClusterIdentifier,Status,PercentProgress]" \
  --output table'
```

---

## Verification and Testing

### Verification Checklist

#### ✅ 1. Cluster Status Verification
```bash
# Compare both clusters
aws docdb describe-db-clusters \
  --query 'DBClusters[?contains(DBClusterIdentifier, `test-mongo`)]' \
  --output json | jq -r '.[] | {
    ClusterID: .DBClusterIdentifier,
    Status: .Status,
    Engine: .Engine,
    Version: .EngineVersion,
    Created: .ClusterCreateTime
  }'
```

#### ✅ 2. CloudTrail Audit Verification
```bash
# Verify restoration event in CloudTrail
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RestoreDBClusterFromSnapshot \
  --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)Z" \
  --query 'Events[0].CloudTrailEvent' \
  --output text | jq '{
    EventName: .eventName,
    EventTime: .eventTime,
    ClusterID: .requestParameters.dBClusterIdentifier,
    SnapshotUsed: .requestParameters.snapshotIdentifier
  }'
```

#### ✅ 3. Instance Details Verification
```bash
# Check instances in the restored cluster
aws docdb describe-db-instances \
  --filters "Name=db-cluster-id,Values=$NEW_CLUSTER_ID" \
  --query 'DBInstances[*].{
    InstanceID: DBInstanceIdentifier,
    Status: DBInstanceStatus,
    Class: DBInstanceClass,
    Role: (PromotionTier == `0` && `Primary` || `Replica`)
  }' \
  --output table
```

#### ✅ 4. Network Configuration Verification
```bash
# Verify network settings
aws docdb describe-db-clusters \
  --db-cluster-identifier "$NEW_CLUSTER_ID" \
  --query 'DBClusters[0].{
    SubnetGroup: DBSubnetGroup,
    SecurityGroups: VpcSecurityGroups[*].VpcSecurityGroupId,
    Port: Port,
    Endpoint: Endpoint,
    ReaderEndpoint: ReaderEndpoint
  }' \
  --output json
```

### Automated Verification Script

Create `verify_restoration.sh`:
```bash
#!/bin/bash

# Configuration
SOURCE_CLUSTER="test-mongo-test-datastore-1155708878-dev-aws"
RESTORED_CLUSTER="test-mongo-new-test-datastore-1155708878-dev-aws"
SNAPSHOT_ID="test-mongo-restore-snapshot-20250908-195008"

echo "========================================"
echo "   DocumentDB Restoration Verification  "
echo "========================================"
echo ""

# 1. Check cluster status
echo "1. Cluster Status Check:"
aws docdb describe-db-clusters \
  --db-cluster-identifier "$RESTORED_CLUSTER" \
  --query 'DBClusters[0].Status' \
  --output text | xargs -I {} echo "   Status: {}"

# 2. Verify snapshot used
echo ""
echo "2. Snapshot Verification:"
aws docdb describe-db-cluster-snapshots \
  --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
  --query 'DBClusterSnapshots[0].{
    SnapshotID: DBClusterSnapshotIdentifier,
    SourceCluster: DBClusterIdentifier,
    Status: Status
  }' \
  --output json | jq -r 'to_entries[] | "   \(.key): \(.value)"'

# 3. Configuration comparison
echo ""
echo "3. Configuration Comparison:"
echo "   Source Cluster:"
aws docdb describe-db-clusters \
  --db-cluster-identifier "$SOURCE_CLUSTER" \
  --query 'DBClusters[0].{
    Engine: Engine,
    Version: EngineVersion,
    Port: Port
  }' \
  --output json | jq -r 'to_entries[] | "      \(.key): \(.value)"'

echo "   Restored Cluster:"
aws docdb describe-db-clusters \
  --db-cluster-identifier "$RESTORED_CLUSTER" \
  --query 'DBClusters[0].{
    Engine: Engine,
    Version: EngineVersion,
    Port: Port
  }' \
  --output json | jq -r 'to_entries[] | "      \(.key): \(.value)"'

# 4. CloudTrail verification
echo ""
echo "4. CloudTrail Audit Log:"
RESTORE_EVENT=$(aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RestoreDBClusterFromSnapshot \
  --max-items 1 \
  --query 'Events[0].CloudTrailEvent' \
  --output text 2>/dev/null | jq -r '.requestParameters.snapshotIdentifier' 2>/dev/null)

if [ "$RESTORE_EVENT" = "$SNAPSHOT_ID" ]; then
  echo "   ✅ Restoration from snapshot verified in CloudTrail"
else
  echo "   ⚠️  Could not verify restoration in CloudTrail"
fi

echo ""
echo "========================================"
echo "         Verification Complete          "
echo "========================================"
```

---

## Connectivity Testing

### Prerequisites for Connection Testing

DocumentDB clusters are typically in private subnets, requiring:
1. **EC2 instance in same VPC** (bastion/jump host)
2. **VPN connection** to the VPC
3. **TLS/SSL certificates** for secure connections

### Method 1: Direct Connection Test (from Bastion Host)

#### 1.1 Download DocumentDB Certificate
```bash
# Download the certificate bundle
wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
```

#### 1.2 Test with MongoDB Shell
```bash
# Set connection variables
CLUSTER_ENDPOINT="test-mongo-new-test-datastore-1155708878-dev-aws.cluster-cevx7rb6ek0k.eu-central-1.docdb.amazonaws.com"
USERNAME="docdbadmin"
PASSWORD="RestorePass123!"

# Connect to restored cluster
mongosh --host $CLUSTER_ENDPOINT:27017 \
  --ssl \
  --sslCAFile global-bundle.pem \
  --username $USERNAME \
  --password $PASSWORD \
  --authenticationDatabase admin
```

#### 1.3 Verify Data
```javascript
// Once connected, run these commands:
// Show all databases
show dbs

// Use a specific database
use your_database_name

// Show collections
show collections

// Count documents in a collection
db.your_collection.countDocuments()

// Sample documents
db.your_collection.find().limit(5)
```

### Method 2: Connection String Testing

#### 2.1 Standard Connection String
```bash
# Format for applications
CONNECTION_STRING="mongodb://$USERNAME:$PASSWORD@$CLUSTER_ENDPOINT:27017/?tls=true&tlsCAFile=global-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"

echo "Connection String: $CONNECTION_STRING"
```

#### 2.2 Python Connection Test
Create `test_connection.py`:
```python
#!/usr/bin/env python3
import pymongo
import ssl
from datetime import datetime

# Configuration
CLUSTER_ENDPOINT = "test-mongo-new-test-datastore-1155708878-dev-aws.cluster-cevx7rb6ek0k.eu-central-1.docdb.amazonaws.com"
USERNAME = "docdbadmin"
PASSWORD = "RestorePass123!"

def test_documentdb_connection():
    try:
        # Create connection string
        connection_string = f"mongodb://{USERNAME}:{PASSWORD}@{CLUSTER_ENDPOINT}:27017/?tls=true&tlsCAFile=global-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
        
        # Connect to DocumentDB
        client = pymongo.MongoClient(connection_string)
        
        # Test connection
        client.admin.command('ping')
        print(f"✅ Successfully connected to DocumentDB at {datetime.now()}")
        
        # List databases
        print("\nDatabases:")
        for db in client.list_database_names():
            print(f"  - {db}")
        
        # Get server info
        server_info = client.server_info()
        print(f"\nServer Version: {server_info.get('version', 'Unknown')}")
        
        client.close()
        return True
        
    except Exception as e:
        print(f"❌ Connection failed: {str(e)}")
        return False

if __name__ == "__main__":
    test_documentdb_connection()
```

### Method 3: Network Connectivity Test

#### 3.1 Port Accessibility Test
```bash
# Test port 27017
nc -zv $CLUSTER_ENDPOINT 27017

# With timeout
timeout 5 nc -zv $CLUSTER_ENDPOINT 27017 && \
  echo "✅ Port 27017 is accessible" || \
  echo "❌ Port 27017 is not accessible"
```

#### 3.2 DNS Resolution Test
```bash
# Resolve cluster endpoint
nslookup $CLUSTER_ENDPOINT

# Get IP addresses
dig +short $CLUSTER_ENDPOINT
```

### Method 4: Comprehensive Connection Test Script

Create `documentdb_connection_test.sh`:
```bash
#!/bin/bash

# Configuration
ORIGINAL_CLUSTER="test-mongo-test-datastore-1155708878-dev-aws.cluster-cevx7rb6ek0k.eu-central-1.docdb.amazonaws.com"
RESTORED_CLUSTER="test-mongo-new-test-datastore-1155708878-dev-aws.cluster-cevx7rb6ek0k.eu-central-1.docdb.amazonaws.com"
USERNAME="docdbadmin"
ORIGINAL_PASSWORD="OriginalPass123!"
RESTORED_PASSWORD="RestorePass123!"

echo "========================================"
echo "     DocumentDB Connection Test         "
echo "========================================"
echo ""

# Function to test connection
test_connection() {
    local endpoint=$1
    local password=$2
    local cluster_type=$3
    
    echo "Testing $cluster_type cluster..."
    
    # Test network connectivity
    timeout 3 nc -zv $endpoint 27017 &>/dev/null
    if [ $? -eq 0 ]; then
        echo "  ✅ Network: Port 27017 accessible"
    else
        echo "  ❌ Network: Port 27017 not accessible"
        return 1
    fi
    
    # Test MongoDB connection
    mongosh --host $endpoint:27017 \
      --ssl \
      --sslCAFile global-bundle.pem \
      --username $USERNAME \
      --password $password \
      --authenticationDatabase admin \
      --quiet \
      --eval "db.adminCommand('ping')" &>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "  ✅ MongoDB: Authentication successful"
        
        # Get database count
        DB_COUNT=$(mongosh --host $endpoint:27017 \
          --ssl \
          --sslCAFile global-bundle.pem \
          --username $USERNAME \
          --password $password \
          --authenticationDatabase admin \
          --quiet \
          --eval "db.adminCommand('listDatabases').databases.length")
        
        echo "  ℹ️  Databases: $DB_COUNT found"
    else
        echo "  ❌ MongoDB: Authentication failed"
        return 1
    fi
    
    echo ""
}

# Download certificate if not present
if [ ! -f global-bundle.pem ]; then
    echo "Downloading DocumentDB certificate..."
    wget -q https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
    echo ""
fi

# Test original cluster
test_connection $ORIGINAL_CLUSTER $ORIGINAL_PASSWORD "ORIGINAL"

# Test restored cluster
test_connection $RESTORED_CLUSTER $RESTORED_PASSWORD "RESTORED"

echo "========================================"
echo "        Connection Test Complete        "
echo "========================================"
```

---

## Debugging and Troubleshooting

### Common Errors and Solutions

#### Error 1: Snapshot Not Found
```
Error: DBClusterSnapshotNotFoundFault
```
**Solution:**
```bash
# List all available snapshots
aws docdb describe-db-cluster-snapshots \
  --query 'DBClusterSnapshots[*].[DBClusterSnapshotIdentifier,Status]' \
  --output table

# Verify snapshot exists and is available
aws docdb describe-db-cluster-snapshots \
  --db-cluster-snapshot-identifier "your-snapshot-id" \
  --output json
```

#### Error 2: Invalid Master Password
```
Error: MasterUserPassword does not meet requirements
```
**Solution:**
- Password must be 8-128 characters
- Cannot contain: /, @, ", or spaces
- Use special characters from: !#$%&*+-=?^_`{|}~

#### Error 3: Connection Timeout
```
Error: Connection timeout to DocumentDB cluster
```
**Solution:**
```bash
# Check security group rules
aws ec2 describe-security-groups \
  --group-ids sg-your-security-group-id \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`27017`]' \
  --output json

# Add rule if missing
aws ec2 authorize-security-group-ingress \
  --group-id sg-your-security-group-id \
  --protocol tcp \
  --port 27017 \
  --source-group sg-your-source-group-id
```

#### Error 4: TLS/SSL Certificate Issues
```
Error: SSL peer certificate validation failed
```
**Solution:**
```bash
# Download latest certificate
wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -O global-bundle.pem

# Verify certificate
openssl x509 -in global-bundle.pem -text -noout | grep "Subject:"
```

### Debugging Commands

#### Check Cluster Events
```bash
# Get recent events for the cluster
aws docdb describe-events \
  --source-type db-cluster \
  --source-identifier "$NEW_CLUSTER_ID" \
  --duration 1440 \
  --output json | jq -r '.Events[] | "\(.Date): \(.Message)"'
```

#### Monitor CloudWatch Metrics
```bash
# CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/DocDB \
  --metric-name CPUUtilization \
  --dimensions Name=DBClusterIdentifier,Value=$NEW_CLUSTER_ID \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --output json | jq '.Datapoints | sort_by(.Timestamp) | .[] | "\(.Timestamp): \(.Average)%"'
```

#### Check Parameter Groups
```bash
# List parameter group settings
aws docdb describe-db-cluster-parameters \
  --db-cluster-parameter-group-name "your-parameter-group" \
  --query 'Parameters[?ParameterValue!=`null`].{Name:ParameterName,Value:ParameterValue}' \
  --output table
```

### Troubleshooting Script

Create `troubleshoot_documentdb.sh`:
```bash
#!/bin/bash

CLUSTER_ID="$1"

if [ -z "$CLUSTER_ID" ]; then
    echo "Usage: $0 <cluster-identifier>"
    exit 1
fi

echo "=== DocumentDB Troubleshooting Report ==="
echo "Cluster: $CLUSTER_ID"
echo "Time: $(date)"
echo ""

# 1. Cluster Status
echo "1. CLUSTER STATUS:"
aws docdb describe-db-clusters \
  --db-cluster-identifier "$CLUSTER_ID" \
  --query 'DBClusters[0].{Status:Status,Engine:Engine,Version:EngineVersion}' \
  --output json | jq -r 'to_entries[] | "   \(.key): \(.value)"'

# 2. Instance Status
echo ""
echo "2. INSTANCE STATUS:"
aws docdb describe-db-instances \
  --filters "Name=db-cluster-id,Values=$CLUSTER_ID" \
  --query 'DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus}' \
  --output table

# 3. Recent Events
echo ""
echo "3. RECENT EVENTS (Last 24 hours):"
aws docdb describe-events \
  --source-type db-cluster \
  --source-identifier "$CLUSTER_ID" \
  --duration 1440 \
  --query 'Events[:5].{Time:Date,Message:Message}' \
  --output json | jq -r '.[] | "   \(.Time): \(.Message)"'

# 4. Network Configuration
echo ""
echo "4. NETWORK CONFIGURATION:"
aws docdb describe-db-clusters \
  --db-cluster-identifier "$CLUSTER_ID" \
  --query 'DBClusters[0].{
    SubnetGroup:DBSubnetGroup,
    SecurityGroups:VpcSecurityGroups[*].VpcSecurityGroupId
  }' \
  --output json | jq -r 'to_entries[] | "   \(.key): \(.value)"'

# 5. Backup Status
echo ""
echo "5. BACKUP STATUS:"
aws docdb describe-db-clusters \
  --db-cluster-identifier "$CLUSTER_ID" \
  --query 'DBClusters[0].{
    BackupRetention:BackupRetentionPeriod,
    BackupWindow:PreferredBackupWindow,
    LatestRestorableTime:LatestRestorableTime
  }' \
  --output json | jq -r 'to_entries[] | "   \(.key): \(.value)"'

echo ""
echo "=== End of Report ==="
```

---

## Best Practices and Security

### Pre-Restoration Checklist
- [ ] Document source cluster configuration
- [ ] Verify snapshot creation window doesn't conflict with peak usage
- [ ] Test restoration process in development environment
- [ ] Prepare rollback plan
- [ ] Notify stakeholders of maintenance window

### During Restoration
- [ ] Monitor CloudTrail for API calls
- [ ] Check CloudWatch metrics continuously
- [ ] Keep detailed logs of all operations
- [ ] Avoid modifications to source cluster
- [ ] Verify security group rules are properly configured

### Post-Restoration Verification
- [ ] Verify all data is present
- [ ] Test application connectivity
- [ ] Check performance metrics
- [ ] Validate backup configuration
- [ ] Update documentation

### Security Best Practices

#### 1. Network Security
```bash
# Ensure cluster is not publicly accessible
aws docdb describe-db-clusters \
  --db-cluster-identifier "$CLUSTER_ID" \
  --query 'DBClusters[0].PubliclyAccessible' \
  --output text

# Should return: False
```

#### 2. Encryption Verification
```bash
# Check encryption status
aws docdb describe-db-clusters \
  --db-cluster-identifier "$CLUSTER_ID" \
  --query 'DBClusters[0].{
    StorageEncrypted:StorageEncrypted,
    KmsKeyId:KmsKeyId
  }' \
  --output json
```

#### 3. Password Rotation
```bash
# After restoration, rotate master password
aws docdb modify-db-cluster \
  --db-cluster-identifier "$CLUSTER_ID" \
  --master-user-password "NewSecurePassword123!" \
  --apply-immediately
```

#### 4. Audit Logging
```bash
# Enable audit logging
aws docdb modify-db-cluster \
  --db-cluster-identifier "$CLUSTER_ID" \
  --cloudwatch-logs-export-configuration '{"EnableLogTypes":["audit"]}' \
  --apply-immediately
```

---

## Common Issues and Solutions

### Issue 1: Slow Restoration Performance
**Symptoms:** Restoration takes longer than expected

**Solutions:**
1. Check snapshot size and adjust expectations
2. Ensure adequate instance class for workload
3. Monitor CloudWatch for resource constraints
4. Consider using larger instance during restore, then scale down

### Issue 2: Connection String Changes
**Symptoms:** Applications cannot connect to restored cluster

**Solutions:**
1. Update application connection strings with new endpoints
2. Verify TLS/SSL certificate is properly configured
3. Check security group rules allow application traffic
4. Ensure replica set name hasn't changed

### Issue 3: Missing Indexes
**Symptoms:** Query performance degradation after restore

**Solutions:**
```javascript
// Check indexes in MongoDB shell
use your_database
db.your_collection.getIndexes()

// Recreate missing indexes if needed
db.your_collection.createIndex({field: 1})
```

### Issue 4: User Authentication Issues
**Symptoms:** Users cannot authenticate to restored cluster

**Solutions:**
```javascript
// Verify users exist
use admin
db.system.users.find()

// Recreate users if needed
db.createUser({
  user: "appuser",
  pwd: "password",
  roles: [{role: "readWrite", db: "your_database"}]
})
```

---

## Automation Scripts

### Complete Restoration Automation

Create `automate_restoration.sh`:
```bash
#!/bin/bash

# Configuration
SOURCE_CLUSTER="$1"
TARGET_NAME="$2"
MASTER_PASSWORD="$3"

if [ $# -ne 3 ]; then
    echo "Usage: $0 <source-cluster> <target-name> <master-password>"
    exit 1
fi

echo "=== Automated DocumentDB Restoration ==="
echo "Source: $SOURCE_CLUSTER"
echo "Target: $TARGET_NAME"
echo ""

# Step 1: Create snapshot
SNAPSHOT_ID="${TARGET_NAME}-restore-$(date +%Y%m%d-%H%M%S)"
echo "Creating snapshot: $SNAPSHOT_ID"

aws docdb create-db-cluster-snapshot \
  --db-cluster-identifier "$SOURCE_CLUSTER" \
  --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
  --output json > /dev/null

# Step 2: Wait for snapshot
echo "Waiting for snapshot to complete..."
while true; do
  STATUS=$(aws docdb describe-db-cluster-snapshots \
    --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
    --query 'DBClusterSnapshots[0].Status' \
    --output text)
  
  if [ "$STATUS" = "available" ]; then
    echo "✅ Snapshot ready"
    break
  fi
  sleep 10
done

# Step 3: Get source configuration
echo "Retrieving source configuration..."
SOURCE_CONFIG=$(aws docdb describe-db-clusters \
  --db-cluster-identifier "$SOURCE_CLUSTER" \
  --query 'DBClusters[0]' \
  --output json)

ENGINE_VERSION=$(echo $SOURCE_CONFIG | jq -r '.EngineVersion')
PORT=$(echo $SOURCE_CONFIG | jq -r '.Port')
SUBNET_GROUP=$(echo $SOURCE_CONFIG | jq -r '.DBSubnetGroup')

# Step 4: Create restoration configuration
cat > restore_config.json <<EOF
{
  "kind": "mongo",
  "flavor": "aws-documentdb",
  "version": "1.0",
  "spec": {
    "version_config": {
      "engine_version": "$ENGINE_VERSION",
      "port": $PORT
    },
    "sizing": {
      "instance_class": "db.t4g.medium",
      "instance_count": 1
    },
    "restore_config": {
      "restore_from_snapshot": true,
      "snapshot_identifier": "$SNAPSHOT_ID",
      "master_username": "docdbadmin",
      "master_password": "$MASTER_PASSWORD"
    }
  }
}
EOF

echo "✅ Restoration configuration created: restore_config.json"
echo ""
echo "Next steps:"
echo "1. Import restore_config.json to Facets control plane"
echo "2. Deploy the $TARGET_NAME resource"
echo "3. Run verification: ./verify_restoration.sh $TARGET_NAME"
```

---

## Conclusion

This comprehensive guide provides everything needed for successful DocumentDB restoration through the Facets control plane. Key takeaways:

1. **Always create snapshots** before any major changes
2. **Verify restoration** through CloudTrail and connection tests
3. **Test in development** before production restoration
4. **Monitor continuously** during and after restoration
5. **Document everything** for audit and troubleshooting

Remember that restoration creates a new cluster with new endpoints - update all applications accordingly.

---

## Quick Reference

### Essential Commands
```bash
# Create snapshot
aws docdb create-db-cluster-snapshot \
  --db-cluster-identifier SOURCE_CLUSTER \
  --db-cluster-snapshot-identifier SNAPSHOT_ID

# Check restoration in CloudTrail
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RestoreDBClusterFromSnapshot

# Test connection
mongosh --host ENDPOINT:27017 --ssl --sslCAFile global-bundle.pem \
  --username USERNAME --password PASSWORD

# Monitor cluster status
aws docdb describe-db-clusters --db-cluster-identifier CLUSTER_ID
```

### Configuration Template
```yaml
restore_config:
  restore_from_snapshot: true
  snapshot_identifier: "snapshot-id"
  master_username: "docdbadmin"
  master_password: "SecurePass123!"
```

### Support Resources
- [AWS DocumentDB Documentation](https://docs.aws.amazon.com/documentdb/)
- [Facets Platform Documentation](https://docs.facets.cloud/)
- [MongoDB Shell Documentation](https://docs.mongodb.com/mongodb-shell/)

---

*Last updated: September 8, 2025*
*Version: 1.0*
*Author: Facets Platform Team*
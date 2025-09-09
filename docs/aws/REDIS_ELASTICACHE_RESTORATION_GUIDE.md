# Redis ElastiCache Restoration Guide

## Overview
This comprehensive guide documents the complete process of restoring AWS ElastiCache Redis clusters using snapshots through the Facets control plane. It includes troubleshooting a critical module bug, fixing it, and successfully performing restoration.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Understanding ElastiCache Restoration](#understanding-elasticache-restoration)
3. [Module Bug Discovery and Fix](#module-bug-discovery-and-fix)
4. [Step-by-Step Restoration Process](#step-by-step-restoration-process)
5. [Verification and Testing](#verification-and-testing)
6. [Connectivity Testing](#connectivity-testing)
7. [Debugging and Troubleshooting](#debugging-and-troubleshooting)
8. [Common Issues and Solutions](#common-issues-and-solutions)
9. [Key Differences from Other Services](#key-differences-from-other-services)

---

## Prerequisites

### Required Access
- AWS CLI configured with appropriate permissions
- Access to Facets control plane
- ElastiCache management permissions:
  - `elasticache:CreateSnapshot`
  - `elasticache:DescribeSnapshots`
  - `elasticache:CreateReplicationGroup`
  - `elasticache:DescribeReplicationGroups`

### Required Tools
```bash
# AWS CLI
aws --version

# jq for JSON parsing
brew install jq  # macOS
apt-get install jq  # Linux

# Redis CLI for connectivity testing
brew install redis  # macOS
apt-get install redis-tools  # Linux

# netcat for port testing
nc -h  # Usually pre-installed
```

### Required Information
- Source Redis cluster identifier
- VPC and subnet group details
- Security group configurations
- Auth token (if enabled)

---

## Understanding ElastiCache Restoration

### How ElastiCache Restoration Works

ElastiCache uses **snapshot-based restoration** which:
1. Takes a point-in-time backup of your Redis cluster
2. Creates a new replication group from the snapshot
3. Preserves all data, but creates new endpoints
4. Maintains security settings but generates new auth tokens

### Key Concepts

| Component | Description |
|-----------|-------------|
| **Replication Group** | The primary ElastiCache Redis resource |
| **Cache Cluster** | Individual nodes within the replication group |
| **Snapshot** | Point-in-time backup stored internally by AWS |
| **snapshot_name** | Parameter for restoring from ElastiCache snapshots |
| **snapshot_arns** | Parameter for restoring from S3 (external dumps) |

### Module Structure
```
redis-aws-elasticache/
├── facets.yaml       # Configuration schema
├── main.tf          # Terraform resources
├── variables.tf     # Input variables
├── locals.tf        # Local computations
└── outputs.tf       # Output definitions
```

---

## Module Bug Discovery and Fix

### The Problem Encountered

**Initial Error:**
```
Error: creating ElastiCache Replication Group (test-redis-new-67006b9f): 
InvalidParameterValue: Must specify an object path for the S3 ARN: 
arn:aws:elasticache:eu-central-1:338360549315:snapshot:test-redis-restore-snapshot-20250908-205545
```

### Root Cause Analysis

The module was using `snapshot_arns` parameter which expects S3 paths for external Redis dumps, not internal ElastiCache snapshots.

```hcl
# INCORRECT - Original code (main.tf line 103)
snapshot_arns = var.instance.spec.restore_config.restore_from_snapshot ? 
                [var.instance.spec.restore_config.snapshot_arns] : null
```

### The Fix Applied

Changed from `snapshot_arns` to `snapshot_name` across 4 files:

#### 1. facets.yaml
```yaml
# BEFORE
snapshot_arns:
  type: string
  title: Snapshot ARN
  
# AFTER  
snapshot_name:
  type: string
  title: Snapshot Name
```

#### 2. variables.tf
```hcl
# BEFORE
snapshot_arns = optional(string)

# AFTER
snapshot_name = optional(string)
```

#### 3. main.tf
```hcl
# BEFORE
snapshot_arns = var.instance.spec.restore_config.restore_from_snapshot ? 
                [var.instance.spec.restore_config.snapshot_arns] : null

# AFTER
snapshot_name = var.instance.spec.restore_config.restore_from_snapshot ? 
                var.instance.spec.restore_config.snapshot_name : null
```

#### 4. main.tf lifecycle
```hcl
# BEFORE
ignore_changes = [snapshot_arns]

# AFTER  
ignore_changes = [snapshot_name]
```

---

## Step-by-Step Restoration Process

### Phase 1: Identify Source Redis Cluster

```bash
# List all ElastiCache replication groups
aws elasticache describe-replication-groups \
  --query 'ReplicationGroups[*].[ReplicationGroupId,Status,CacheNodeType]' \
  --output table

# Get specific cluster details
CLUSTER_ID="test-redis-b0607058"
aws elasticache describe-replication-groups \
  --replication-group-id "$CLUSTER_ID" \
  --output json | jq '{
    ReplicationGroupId,
    Status,
    CacheNodeType,
    Engine,
    PrimaryEndpoint: .NodeGroups[0].PrimaryEndpoint.Address,
    MemberClusters
  }'
```

### Phase 2: Create Snapshot

```bash
# Get the cache cluster ID (member of replication group)
CACHE_CLUSTER_ID=$(aws elasticache describe-replication-groups \
  --replication-group-id "$CLUSTER_ID" \
  --query 'ReplicationGroups[0].MemberClusters[0]' \
  --output text)

echo "Cache Cluster ID: $CACHE_CLUSTER_ID"

# IMPORTANT: Check cluster is not already snapshotting
STATUS=$(aws elasticache describe-cache-clusters \
  --cache-cluster-id "$CACHE_CLUSTER_ID" \
  --query 'CacheClusters[0].CacheClusterStatus' \
  --output text)

if [ "$STATUS" != "available" ]; then
  echo "Waiting for cluster to become available (current: $STATUS)..."
  # Wait loop here
fi

# Create snapshot with timestamp
SNAPSHOT_NAME="redis-restore-snapshot-$(date +%Y%m%d-%H%M%S)"
aws elasticache create-snapshot \
  --cache-cluster-id "$CACHE_CLUSTER_ID" \
  --snapshot-name "$SNAPSHOT_NAME" \
  --output json
```

### Phase 3: Wait for Snapshot Completion

```bash
#!/bin/bash
# wait_for_snapshot.sh

SNAPSHOT_NAME="$1"

echo "Waiting for snapshot: $SNAPSHOT_NAME"

while true; do
  STATUS=$(aws elasticache describe-snapshots \
    --snapshot-name "$SNAPSHOT_NAME" \
    --query 'Snapshots[0].SnapshotStatus' \
    --output text)
  
  echo "Status: $STATUS"
  
  if [ "$STATUS" = "available" ]; then
    echo "✅ Snapshot ready!"
    break
  elif [ "$STATUS" = "failed" ]; then
    echo "❌ Snapshot failed!"
    exit 1
  fi
  
  sleep 10
done

# Get snapshot details
aws elasticache describe-snapshots \
  --snapshot-name "$SNAPSHOT_NAME" \
  --output json | jq '{
    SnapshotName,
    SnapshotStatus,
    CacheClusterId,
    ARN
  }'
```

### Phase 4: Configure Restoration in Facets

**In Facets Control Plane:**

1. Navigate to your environment
2. Create or select target resource (e.g., `test-redis-new`)
3. Configure the following:

```yaml
Restore Operations:
  ✅ Restore from Snapshot: true
  Snapshot Name: redis-restore-snapshot-20250908-221412  # Just the name!

Version & Basic Configuration:
  Redis Version: 7.0
  Node Type: cache.t3.small

Sizing & Performance:
  Number of Cache Nodes: 1  # or 2 for HA
  Parameter Group: default.redis7
  Snapshot Retention: 7
```

### Phase 5: Deploy and Monitor

```bash
# After deployment, monitor the new cluster
NEW_CLUSTER_ID="test-redis-new-67006b9f"

# Check status
aws elasticache describe-replication-groups \
  --replication-group-id "$NEW_CLUSTER_ID" \
  --query 'ReplicationGroups[0].Status' \
  --output text

# Monitor events
aws elasticache describe-events \
  --source-identifier "$NEW_CLUSTER_ID" \
  --source-type "replication-group" \
  --duration 60 \
  --output json | jq '.Events[] | {Date, Message}'
```

---

## Verification and Testing

### Comprehensive Verification Script

```bash
#!/bin/bash
# verify_restoration.sh

ORIGINAL_CLUSTER="test-redis-b0607058"
RESTORED_CLUSTER="test-redis-new-67006b9f"
SNAPSHOT_NAME="redis-restore-snapshot-20250908-221412"

echo "=== REDIS ELASTICACHE RESTORATION VERIFICATION ==="
echo ""

# 1. Check both clusters exist and are available
echo "1. CLUSTER STATUS:"
for cluster in $ORIGINAL_CLUSTER $RESTORED_CLUSTER; do
  STATUS=$(aws elasticache describe-replication-groups \
    --replication-group-id "$cluster" \
    --query 'ReplicationGroups[0].Status' \
    --output text)
  echo "   $cluster: $STATUS"
done

# 2. Compare configurations
echo ""
echo "2. CONFIGURATION COMPARISON:"
echo "   Original:"
aws elasticache describe-replication-groups \
  --replication-group-id "$ORIGINAL_CLUSTER" \
  --query 'ReplicationGroups[0].{
    NodeType:CacheNodeType,
    Engine:Engine,
    NumNodes:MemberClusters|length(@),
    Auth:AuthTokenEnabled,
    Encryption:TransitEncryptionEnabled
  }' --output json | jq -c

echo "   Restored:"
aws elasticache describe-replication-groups \
  --replication-group-id "$RESTORED_CLUSTER" \
  --query 'ReplicationGroups[0].{
    NodeType:CacheNodeType,
    Engine:Engine,
    NumNodes:MemberClusters|length(@),
    Auth:AuthTokenEnabled,
    Encryption:TransitEncryptionEnabled
  }' --output json | jq -c

# 3. Verify restoration events
echo ""
echo "3. RESTORATION EVENTS:"
aws elasticache describe-events \
  --source-identifier "$RESTORED_CLUSTER-001" \
  --source-type "cache-cluster" \
  --duration 120 \
  --query 'Events[?contains(Message, `Restore`)].[Date,Message]' \
  --output text

# 4. Get endpoints
echo ""
echo "4. CONNECTION ENDPOINTS:"
echo "   Original: $(aws elasticache describe-replication-groups \
  --replication-group-id "$ORIGINAL_CLUSTER" \
  --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' \
  --output text):6379"

echo "   Restored: $(aws elasticache describe-replication-groups \
  --replication-group-id "$RESTORED_CLUSTER" \
  --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' \
  --output text):6379"

echo ""
echo "=== VERIFICATION COMPLETE ==="
```

### Expected Restoration Events

Unlike DocumentDB, ElastiCache **DOES** show restoration in events:
- "Restore from snapshot is in progress for node group 0001"
- "Restore from snapshot succeeded for node group 0001"
- "Cache cluster created"
- "Replication group created"

---

## Connectivity Testing

### Prerequisites for Testing

Since ElastiCache clusters are in private subnets:
1. EC2 instance in the same VPC (bastion host)
2. Security group allowing Redis port (6379)
3. Auth token from the cluster

### Method 1: Using Redis CLI

```bash
# Get auth token (stored in outputs or Secrets Manager)
AUTH_TOKEN="your-auth-token"
ENDPOINT="master.test-redis-new-67006b9f.lojl15.euc1.cache.amazonaws.com"

# Test connection with auth and TLS
redis-cli -h $ENDPOINT \
  -p 6379 \
  --tls \
  --cacert /path/to/ca-cert.pem \
  -a $AUTH_TOKEN \
  ping

# Expected response: PONG
```

### Method 2: Port Connectivity Test

```bash
# From bastion host in same VPC
ENDPOINT="master.test-redis-new-67006b9f.lojl15.euc1.cache.amazonaws.com"

# Test port accessibility
nc -zv $ENDPOINT 6379

# With timeout
timeout 5 nc -zv $ENDPOINT 6379 && \
  echo "✅ Port 6379 accessible" || \
  echo "❌ Port 6379 not accessible"
```

### Method 3: Python Connection Test

```python
#!/usr/bin/env python3
# test_redis_connection.py

import redis
import ssl

# Configuration
ENDPOINT = "master.test-redis-new-67006b9f.lojl15.euc1.cache.amazonaws.com"
PORT = 6379
AUTH_TOKEN = "your-auth-token"

def test_connection():
    try:
        # Create SSL context
        ssl_context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_REQUIRED
        
        # Connect to Redis
        client = redis.Redis(
            host=ENDPOINT,
            port=PORT,
            password=AUTH_TOKEN,
            ssl=True,
            ssl_cert_reqs='required',
            ssl_ca_certs='/path/to/ca-cert.pem',
            ssl_context=ssl_context,
            decode_responses=True
        )
        
        # Test connection
        response = client.ping()
        print(f"✅ Connection successful: {response}")
        
        # Test basic operations
        client.set('test_key', 'test_value')
        value = client.get('test_key')
        print(f"✅ Read/Write test: {value}")
        
        # Get info
        info = client.info('server')
        print(f"Redis Version: {info.get('redis_version', 'Unknown')}")
        
        client.close()
        return True
        
    except Exception as e:
        print(f"❌ Connection failed: {str(e)}")
        return False

if __name__ == "__main__":
    test_connection()
```

### Method 4: Data Verification

```bash
# Connect to both clusters and verify data
# Note: Auth tokens will be different for each cluster

# Original cluster
redis-cli -h $ORIGINAL_ENDPOINT -a $ORIGINAL_AUTH --tls << EOF
INFO keyspace
DBSIZE
EOF

# Restored cluster  
redis-cli -h $RESTORED_ENDPOINT -a $RESTORED_AUTH --tls << EOF
INFO keyspace
DBSIZE
EOF
```

---

## Debugging and Troubleshooting

### Common Issues and Solutions

#### Issue 1: "InvalidParameterValue: Must specify an object path for S3 ARN"
**Cause:** Module using `snapshot_arns` instead of `snapshot_name`
**Solution:** Fix the module as shown in the Module Bug Fix section

#### Issue 2: "InvalidCacheClusterState: Cluster must be in available state"
**Cause:** Cluster is already performing another operation (e.g., automatic backup)
**Solution:**
```bash
# Wait for cluster to be available
while [ "$(aws elasticache describe-cache-clusters \
  --cache-cluster-id "CLUSTER_ID" \
  --query 'CacheClusters[0].CacheClusterStatus' \
  --output text)" != "available" ]; do
  echo "Waiting for cluster..."
  sleep 10
done
```

#### Issue 3: Connection Timeout
**Cause:** Security group or network ACL blocking traffic
**Solution:**
```bash
# Check security group rules
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`6379`]'

# Add rule if missing
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 6379 \
  --source-group sg-yyyyy
```

#### Issue 4: Authentication Failed
**Cause:** Wrong auth token or token rotation
**Solution:**
- Auth tokens are different for original and restored clusters
- New auth token is generated during restoration
- Check Secrets Manager or parameter store for new token

### Debugging Commands

```bash
# Check cluster events
aws elasticache describe-events \
  --source-identifier "CLUSTER_ID" \
  --duration 1440 \
  --output json | jq '.Events[] | select(.Message | contains("error"))'

# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name CPUUtilization \
  --dimensions Name=CacheClusterId,Value=CLUSTER_ID \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Check parameter groups
aws elasticache describe-cache-parameter-groups \
  --cache-parameter-group-name "default.redis7"
```

### Troubleshooting Script

```bash
#!/bin/bash
# troubleshoot_redis.sh

CLUSTER_ID="$1"

if [ -z "$CLUSTER_ID" ]; then
  echo "Usage: $0 <replication-group-id>"
  exit 1
fi

echo "=== REDIS TROUBLESHOOTING REPORT ==="
echo "Cluster: $CLUSTER_ID"
echo ""

# 1. Basic status
echo "1. REPLICATION GROUP STATUS:"
aws elasticache describe-replication-groups \
  --replication-group-id "$CLUSTER_ID" \
  --query 'ReplicationGroups[0].{
    Status:Status,
    MultiAZ:MultiAZ,
    AutoFailover:AutomaticFailover
  }' --output json

# 2. Cache clusters status
echo ""
echo "2. CACHE CLUSTER STATUS:"
CACHE_CLUSTERS=$(aws elasticache describe-replication-groups \
  --replication-group-id "$CLUSTER_ID" \
  --query 'ReplicationGroups[0].MemberClusters[]' \
  --output text)

for cluster in $CACHE_CLUSTERS; do
  aws elasticache describe-cache-clusters \
    --cache-cluster-id "$cluster" \
    --query 'CacheClusters[0].{
      ID:CacheClusterId,
      Status:CacheClusterStatus,
      Node:CacheNodes[0].CacheNodeStatus
    }' --output json
done

# 3. Recent events
echo ""
echo "3. RECENT EVENTS (Last 2 hours):"
aws elasticache describe-events \
  --source-identifier "$CLUSTER_ID" \
  --source-type "replication-group" \
  --duration 120 \
  --query 'Events[:5].[Date,Message]' \
  --output text

# 4. Network configuration
echo ""
echo "4. NETWORK CONFIGURATION:"
aws elasticache describe-replication-groups \
  --replication-group-id "$CLUSTER_ID" \
  --query 'ReplicationGroups[0].{
    SubnetGroup:CacheSubnetGroupName,
    SecurityGroups:SecurityGroups[*].SecurityGroupId
  }' --output json

echo ""
echo "=== END REPORT ==="
```

---

## Key Differences from Other Services

### ElastiCache vs DocumentDB vs RDS

| Feature | ElastiCache | DocumentDB | RDS |
|---------|------------|------------|-----|
| **Restoration Method** | snapshot_name | snapshot_identifier | Point-in-time |
| **Events Show Restore** | ✅ Yes | ❌ No | ✅ Yes |
| **Snapshot Location** | Internal | Internal | Internal |
| **S3 Export Support** | Via snapshot_arns | Not needed | Not needed |
| **Auth Token** | New generated | Password provided | Password provided |
| **Endpoints** | New created | New created | New created |

### Important Notes

1. **ElastiCache Shows Events:** Unlike DocumentDB, restoration events ARE visible
2. **Parameter Naming:** Use `snapshot_name` for internal snapshots, not `snapshot_arns`
3. **Auth Token:** Always changes during restoration - plan accordingly
4. **Cluster IDs:** Include hash suffixes (e.g., test-redis-b0607058)
5. **Cache Cluster vs Replication Group:** Snapshots are taken from cache clusters, not replication groups

---

## Best Practices

### Before Restoration
1. **Verify cluster status** - Must be "available"
2. **Document auth tokens** - Will change after restore
3. **Test in development** first
4. **Plan for endpoint changes** in applications

### During Restoration
1. **Monitor events** - ElastiCache provides good event visibility
2. **Wait for completion** - Don't rush the process
3. **Keep snapshot names** organized with timestamps
4. **Document the snapshot used** for audit trail

### After Restoration
1. **Update auth tokens** in application configurations
2. **Update endpoints** in connection strings
3. **Verify data integrity** with key counts
4. **Monitor performance** for cache warming period
5. **Test failover** if using Multi-AZ

### Security Considerations
1. **Transit Encryption:** Always enabled in production
2. **At-Rest Encryption:** Cannot be changed after creation
3. **Auth Tokens:** Store securely in Secrets Manager
4. **Network Isolation:** Keep in private subnets
5. **Security Groups:** Restrict to application subnets only

---

## Automation Example

### Complete Restoration Automation

```bash
#!/bin/bash
# automate_redis_restore.sh

set -e

SOURCE_CLUSTER="$1"
TARGET_NAME="$2"

if [ $# -ne 2 ]; then
  echo "Usage: $0 <source-cluster> <target-name>"
  exit 1
fi

echo "=== Automated Redis Restoration ==="
echo "Source: $SOURCE_CLUSTER"
echo "Target: $TARGET_NAME"
echo ""

# Step 1: Get cache cluster ID
CACHE_CLUSTER=$(aws elasticache describe-replication-groups \
  --replication-group-id "$SOURCE_CLUSTER" \
  --query 'ReplicationGroups[0].MemberClusters[0]' \
  --output text)

echo "Cache Cluster: $CACHE_CLUSTER"

# Step 2: Wait for availability
echo "Checking cluster status..."
while [ "$(aws elasticache describe-cache-clusters \
  --cache-cluster-id "$CACHE_CLUSTER" \
  --query 'CacheClusters[0].CacheClusterStatus' \
  --output text)" != "available" ]; do
  echo "  Waiting for cluster to be available..."
  sleep 10
done

# Step 3: Create snapshot
SNAPSHOT_NAME="${TARGET_NAME}-snapshot-$(date +%Y%m%d-%H%M%S)"
echo "Creating snapshot: $SNAPSHOT_NAME"

aws elasticache create-snapshot \
  --cache-cluster-id "$CACHE_CLUSTER" \
  --snapshot-name "$SNAPSHOT_NAME"

# Step 4: Wait for snapshot
echo "Waiting for snapshot completion..."
while [ "$(aws elasticache describe-snapshots \
  --snapshot-name "$SNAPSHOT_NAME" \
  --query 'Snapshots[0].SnapshotStatus' \
  --output text)" != "available" ]; do
  echo "  Snapshot in progress..."
  sleep 10
done

echo "✅ Snapshot ready: $SNAPSHOT_NAME"

# Step 5: Output configuration
cat << EOF

=== FACETS CONFIGURATION ===
Use these settings in the control plane:

Restore Operations:
  ✅ Restore from Snapshot: true
  Snapshot Name: $SNAPSHOT_NAME

Deploy the $TARGET_NAME resource with this configuration.
EOF
```

---

## Conclusion

This guide covers the complete ElastiCache Redis restoration process, including:
1. **Module bug discovery and fix** - Changed from snapshot_arns to snapshot_name
2. **Successful restoration** - Verified through events and configuration matching
3. **Key insight** - ElastiCache shows restoration events, unlike DocumentDB

The fixed module is now published and ready for use with proper snapshot restoration support.

---

## Quick Reference

### Essential Commands
```bash
# Create snapshot
aws elasticache create-snapshot \
  --cache-cluster-id "cluster-001" \
  --snapshot-name "snapshot-name"

# Check snapshot status
aws elasticache describe-snapshots \
  --snapshot-name "snapshot-name"

# Check restoration events
aws elasticache describe-events \
  --source-identifier "cluster-id" \
  --duration 60

# Test connection
redis-cli -h endpoint -p 6379 --tls -a auth_token ping
```

### Module Configuration
```yaml
restore_config:
  restore_from_snapshot: true
  snapshot_name: "snapshot-name"  # NOT snapshot_arns!
```

---

*Last updated: September 8, 2025*
*Version: 1.0*
*Module Version: redis-aws-elasticache 1.0 (fixed)*
# Why DocumentDB Events Don't Show Snapshot Information

## The Mystery: Missing Restore Information in Events

When you restore a DocumentDB cluster from a snapshot, the Events section shows only:
- "DB cluster created"
- Parameter group updates

But it **does NOT show**:
- Which snapshot was used
- That it was restored (not just created)
- The source cluster information

## Why This Happens: AWS Service Differences

### 1. DocumentDB vs RDS Event Logging

| Aspect | RDS (MySQL/PostgreSQL) | DocumentDB |
|--------|------------------------|------------|
| Restore Event Message | "Restored from DB instance X to timestamp Y" | "DB cluster created" |
| Snapshot Reference | Shows in events | Not shown in events |
| Event Detail Level | Detailed restoration info | Generic creation message |
| API Operation Logged | Yes (RestoreDBInstanceToPointInTime) | Yes (RestoreDBClusterFromSnapshot) but not in events |

### 2. Technical Explanation

**DocumentDB's Event System:**
- DocumentDB treats restored clusters as "new creations" in the Events API
- The restoration context is lost after the cluster is created
- Events focus on operational status, not historical lineage

**RDS's Event System:**
- RDS explicitly logs restoration as a special type of creation
- Maintains restoration context in event messages
- Provides detailed restoration metadata

### 3. Where the Information Actually Lives

Despite not appearing in Events, the restoration IS recorded:

#### CloudTrail (Most Reliable) ✅
```bash
# This ALWAYS shows the restoration details
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RestoreDBClusterFromSnapshot \
  --query 'Events[0].CloudTrailEvent' \
  --output text | jq '.requestParameters'

# Output shows:
{
  "dBClusterIdentifier": "test-mongo-new-...",
  "snapshotIdentifier": "test-mongo-restore-snapshot-20250908-195008",
  ...
}
```

#### AWS Console Activity History ✅
- CloudTrail Event History in AWS Console
- Shows RestoreDBClusterFromSnapshot API calls
- Includes full request parameters

#### Terraform State (If Using IaC) ✅
- Terraform state file maintains snapshot_identifier
- Shows in plan/apply outputs
- Preserved in state history

## How to Verify Restoration Without Events

### Method 1: CloudTrail API Audit
```bash
#!/bin/bash
# Get restoration proof from CloudTrail

CLUSTER_ID="test-mongo-new-test-datastore-1155708878-dev-aws"

# Find the RestoreDBClusterFromSnapshot event
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=$CLUSTER_ID \
  --query 'Events[?EventName==`RestoreDBClusterFromSnapshot`].[EventTime,CloudTrailEvent]' \
  --output text | while read -r time event; do
    echo "Restoration Time: $time"
    echo "$event" | jq '.requestParameters | {
      ClusterID: .dBClusterIdentifier,
      SnapshotUsed: .snapshotIdentifier
    }'
done
```

### Method 2: Cluster Creation Time Analysis
```bash
# Compare creation times
# A restored cluster has a creation time AFTER the snapshot creation

# Original cluster
aws docdb describe-db-clusters \
  --db-cluster-identifier "test-mongo-..." \
  --query 'DBClusters[0].ClusterCreateTime' \
  --output text

# Snapshot
aws docdb describe-db-cluster-snapshots \
  --db-cluster-snapshot-identifier "snapshot-id" \
  --query 'DBClusterSnapshots[0].SnapshotCreateTime' \
  --output text

# Restored cluster (will be newest)
aws docdb describe-db-clusters \
  --db-cluster-identifier "test-mongo-new-..." \
  --query 'DBClusters[0].ClusterCreateTime' \
  --output text
```

### Method 3: Configuration Matching
```bash
# Restored clusters have identical configurations to their source
# Check for matching:
# - Engine version
# - Parameter groups (similar names)
# - Network configuration
# - Encryption settings
```

## Why AWS Designed It This Way

### 1. Service Architecture Differences
- **RDS**: Instances with point-in-time recovery focus
- **DocumentDB**: Clusters with snapshot-based recovery focus

### 2. Event Granularity Philosophy
- **RDS**: Detailed operational history
- **DocumentDB**: Simplified status reporting

### 3. Compliance and Audit Requirements
- Both services log to CloudTrail for audit compliance
- Events API is for operational monitoring, not audit trail

## Best Practices for Tracking Restorations

### 1. Tag Your Resources
```bash
# Add tags during restoration to track lineage
aws docdb add-tags-to-resource \
  --resource-name "arn:aws:rds:region:account:cluster:cluster-id" \
  --tags '[
    {"Key":"RestoreSource","Value":"test-mongo"},
    {"Key":"RestoreSnapshot","Value":"snapshot-20250908-195008"},
    {"Key":"RestoreDate","Value":"2025-09-08"}
  ]'
```

### 2. Document in Parameter Descriptions
```bash
# Use cluster parameter group description
aws docdb create-db-cluster-parameter-group \
  --db-cluster-parameter-group-name "restored-cluster-params" \
  --db-parameter-group-family "docdb5.0" \
  --description "Restored from test-mongo snapshot-20250908-195008"
```

### 3. Maintain External Documentation
- Keep restoration logs in your documentation system
- Record snapshot IDs and restoration times
- Document the restoration reason and approver

### 4. Use Automation with Logging
```bash
#!/bin/bash
# Always log restoration operations

LOG_FILE="/var/log/documentdb-restorations.log"
SNAPSHOT_ID="$1"
NEW_CLUSTER="$2"

echo "[$(date)] Restoring $NEW_CLUSTER from $SNAPSHOT_ID" >> $LOG_FILE

# Perform restoration
aws docdb restore-db-cluster-from-snapshot \
  --db-cluster-identifier "$NEW_CLUSTER" \
  --snapshot-identifier "$SNAPSHOT_ID" \
  --engine docdb

echo "[$(date)] Restoration initiated, check CloudTrail for details" >> $LOG_FILE
```

## Comparison Table: Where to Find Restoration Evidence

| Method | RDS | DocumentDB | Reliability |
|--------|-----|------------|-------------|
| Events API | ✅ Shows "Restored from..." | ❌ Shows only "created" | Low for DocDB |
| CloudTrail | ✅ Full details | ✅ Full details | High |
| describe-db-clusters | ❌ No snapshot info | ❌ No snapshot info | None |
| Creation Time | ✅ Indicates restore | ✅ Indicates restore | Medium |
| Resource Tags | ✅ If manually added | ✅ If manually added | High if used |
| Parameter Group Desc | ✅ If documented | ✅ If documented | Medium |

## Conclusion

The absence of snapshot information in DocumentDB Events is a **design choice by AWS**, not a bug. Unlike RDS, DocumentDB's Events API focuses on current operational status rather than historical lineage.

**Key Takeaways:**
1. **Always use CloudTrail** for restoration verification
2. **Don't rely on Events API** for restoration proof in DocumentDB
3. **Implement tagging** for better tracking
4. **Document externally** for audit trails
5. **Understand the service differences** between RDS and DocumentDB

This behavior is consistent across all DocumentDB restorations and is not specific to your restoration. It's a fundamental difference in how AWS implemented the Events API for these services.

---

*Note: This behavior is documented indirectly in AWS documentation but not explicitly called out as a difference from RDS, leading to confusion for users familiar with RDS restoration patterns.*
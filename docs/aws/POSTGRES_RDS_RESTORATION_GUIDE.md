# PostgreSQL RDS Snapshot Restoration Guide

## Overview
This comprehensive guide demonstrates how to create snapshots of existing PostgreSQL RDS instances and restore them to new instances using the Facets control plane. This guide is based on a real-world restoration process and includes all debugging, testing, and verification steps.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Understanding Snapshot-Based Restoration](#understanding-snapshot-based-restoration)
3. [Step-by-Step Restoration Process](#step-by-step-restoration-process)
4. [Verification and Testing](#verification-and-testing)
5. [Debugging and Troubleshooting](#debugging-and-troubleshooting)
6. [Connectivity Testing](#connectivity-testing)
7. [Common Issues and Solutions](#common-issues-and-solutions)

---

## Prerequisites

### Required Access and Tools
- AWS CLI configured with appropriate RDS permissions
- Access to Facets control plane
- PostgreSQL client (psql) for testing
- Network connectivity to test database connections

### Required Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds:DescribeDBInstances",
                "rds:DescribeDBSnapshots", 
                "rds:CreateDBSnapshot",
                "rds:DescribeEvents",
                "rds:RestoreDBInstanceFromDBSnapshot"
            ],
            "Resource": "*"
        }
    ]
}
```

### Information You'll Need
- Source database instance identifier
- Master username and password from source database
- Target resource name in Facets control plane

---

## Understanding Snapshot-Based Restoration

### How It Works
Unlike point-in-time restoration, the Facets PostgreSQL aws-rds module uses **manual snapshots** for restoration:

1. **Manual snapshot creation** using AWS CLI
2. **Snapshot-based restoration** using `snapshot_identifier` parameter
3. **Complete data preservation** from the exact moment of snapshot creation
4. **Credential inheritance** from the snapshot

### Key Files in aws-rds Module
```
datastore/postgres/aws-rds/1.0/
├── facets.yaml     # Configuration with restore_config section
├── main.tf         # Terraform with snapshot_identifier logic
├── variables.tf    # restore_config variable definitions
└── outputs.tf      # Output definitions for restored instance
```

### Restoration Logic in main.tf
```hcl
# Lines 103-104: Conditional credential handling
username = var.instance.spec.restore_config.restore_from_backup ? null : local.master_username
password = var.instance.spec.restore_config.restore_from_backup ? null : local.master_password

# Line 132: Snapshot restoration
snapshot_identifier = var.instance.spec.restore_config.restore_from_backup ? 
  var.instance.spec.restore_config.source_db_instance_identifier : null
```

**Important:** The `source_db_instance_identifier` field accepts snapshot IDs/ARNs, not instance IDs for restoration.

---

## Step-by-Step Restoration Process

### Phase 1: Identify and Analyze Source Database

1. **List all PostgreSQL RDS instances:**
   ```bash
   aws rds describe-db-instances \
     --query "DBInstances[*].[DBInstanceIdentifier, DBInstanceStatus, Engine, EngineVersion, DBInstanceClass]" \
     --output table
   ```

2. **Get source database details:**
   ```bash
   aws rds describe-db-instances \
     --db-instance-identifier your-source-db-identifier \
     --query "DBInstances[0].[DBInstanceIdentifier, MasterUsername, DBName, Endpoint.Address, Endpoint.Port]" \
     --output json
   ```

   **Example output:**
   ```json
   [
       "test-pg-rds-test-datastore-1155708878-dev-aws",
       "pgadmin4f612367", 
       "postgres",
       "test-pg-rds-test-datastore-1155708878-dev-aws.cevx7rb6ek0k.eu-central-1.rds.amazonaws.com",
       5432
   ]
   ```

3. **Record the following information:**
   - DB Instance Identifier: `test-pg-rds-test-datastore-1155708878-dev-aws`
   - Master Username: `pgadmin4f612367`
   - Database Name: `postgres`
   - Endpoint: `test-pg-rds-test-datastore-1155708878-dev-aws.cevx7rb6ek0k.eu-central-1.rds.amazonaws.com`

### Phase 2: Create Manual Snapshot

1. **Create a manual snapshot:**
   ```bash
   aws rds create-db-snapshot \
     --db-instance-identifier test-pg-rds-test-datastore-1155708878-dev-aws \
     --db-snapshot-identifier test-pg-rds-snapshot-for-restore-$(date +%Y%m%d-%H%M%S)
   ```

2. **Monitor snapshot creation:**
   ```bash
   aws rds describe-db-snapshots \
     --db-snapshot-identifier your-snapshot-identifier \
     --query "DBSnapshots[0].[DBSnapshotIdentifier, Status, PercentProgress]" \
     --output json
   ```

3. **Wait for snapshot completion:**
   ```bash
   # Keep checking until status shows "available" and PercentProgress is 100
   # Example output when complete:
   [
       "test-pg-rds-snapshot-for-restore-20250908-114851",
       "available", 
       100
   ]
   ```

   **Typical snapshot creation time:** 5-15 minutes depending on database size

### Phase 3: Configure Restoration in Control Plane

1. **Navigate to your target resource** in the Facets control plane (e.g., `test-pg-rds-new`)

2. **Configure the restore_config section:**
   ```yaml
   Restore from Backup: true
   Source DB Instance Identifier: test-pg-rds-snapshot-for-restore-20250908-114851
   Master Username: pgadmin4f612367
   Master Password: [original-password-from-source-db]
   ```

   **Critical Note:** Use the **SNAPSHOT ID**, not the source instance ID in the `Source DB Instance Identifier` field.

3. **Verify configuration before deployment:**
   - ✅ Restore from Backup: `true`  
   - ✅ Snapshot ID in Source DB Instance Identifier field
   - ✅ Correct master username from source
   - ✅ Correct master password from source

### Phase 4: Deploy and Monitor

1. **Deploy the resource** through the Facets control plane

2. **Monitor deployment progress:**
   ```bash
   # Check instance status
   aws rds describe-db-instances \
     --query "DBInstances[*].[DBInstanceIdentifier, DBInstanceStatus, Engine]" \
     --output table
   ```

3. **Monitor restoration events:**
   ```bash
   aws rds describe-events \
     --source-identifier your-new-db-identifier \
     --source-type db-instance \
     --start-time $(date -u -v-2H +%Y-%m-%dT%H:%M:%S) \
     --query "Events[*].[Date, Message]" \
     --output table
   ```

4. **Expected deployment timeline:**
   - Initial restoration: 1-2 minutes
   - Multi-AZ conversion: 15-20 minutes  
   - First backup: 3-5 minutes
   - Total time: ~20-30 minutes

---

## Verification and Testing

### Phase 1: Restoration Evidence Verification

1. **Confirm snapshot was used:**
   ```bash
   aws rds describe-events \
     --source-identifier your-new-db-identifier \
     --source-type db-instance \
     --query "Events[?contains(Message, 'snapshot')].[Date, Message]" \
     --output table
   ```

   **Expected output:**
   ```
   |  2025-09-08T07:51:44.211000+00:00 |  Restored from snapshot test-pg-rds-snapshot-for-restore-20250908-114851 |
   ```

2. **Verify timeline consistency:**
   ```bash
   # Check snapshot creation time vs instance creation time
   echo "=== SNAPSHOT CREATION ===" && \
   aws rds describe-db-snapshots \
     --db-snapshot-identifier your-snapshot-id \
     --query "DBSnapshots[0].[DBSnapshotIdentifier, SnapshotCreateTime, Status]" \
     --output json && \
   echo -e "\n=== INSTANCE RESTORATION ===" && \
   aws rds describe-db-instances \
     --db-instance-identifier your-new-db-identifier \
     --query "DBInstances[0].InstanceCreateTime" \
     --output json
   ```

### Phase 2: Configuration Comparison

1. **Compare instance configurations:**
   ```bash
   echo "=== ORIGINAL INSTANCE ===" && \
   aws rds describe-db-instances \
     --db-instance-identifier your-original-db \
     --query "DBInstances[0].[MasterUsername, DBName, EngineVersion, AllocatedStorage, DBInstanceClass]" \
     --output json && \
   echo -e "\n=== RESTORED INSTANCE ===" && \
   aws rds describe-db-instances \
     --db-instance-identifier your-new-db \
     --query "DBInstances[0].[MasterUsername, DBName, EngineVersion, AllocatedStorage, DBInstanceClass]" \
     --output json
   ```

2. **Verify security and backup settings:**
   ```bash
   aws rds describe-db-instances \
     --query "DBInstances[?contains(DBInstanceIdentifier, 'your-db-prefix')].[DBInstanceIdentifier, StorageEncrypted, MultiAZ, BackupRetentionPeriod, DeletionProtection]" \
     --output table
   ```

### Phase 3: Complete Event Timeline Verification

```bash
aws rds describe-events \
  --source-identifier your-new-db-identifier \
  --source-type db-instance \
  --start-time $(date -u -v-2H +%Y-%m-%dT%H:%M:%S) \
  --query "Events[*].[Date, Message]" \
  --output table
```

**Expected event sequence:**
```
|  07:51:44  |  Restored from snapshot test-pg-rds-snapshot-for-restore-20250908-114851  |
|  07:51:47  |  Applying modification to convert to a Multi-AZ DB Instance               |
|  08:06:06  |  Finished applying modification to convert to a Multi-AZ DB Instance      |
|  08:07:21  |  Backing up DB instance                                                   |
|  08:10:24  |  Finished DB Instance backup                                              |
|  08:13:20  |  Performance Insights has been enabled                                    |
```

---

## Connectivity Testing

### Method 1: Database Connection Testing

1. **Get database endpoints:**
   ```bash
   echo "=== ORIGINAL DB ENDPOINT ===" && \
   aws rds describe-db-instances \
     --db-instance-identifier your-original-db \
     --query "DBInstances[0].Endpoint.Address" \
     --output text && \
   echo -e "\n=== RESTORED DB ENDPOINT ===" && \
   aws rds describe-db-instances \
     --db-instance-identifier your-restored-db \
     --query "DBInstances[0].Endpoint.Address" \
     --output text
   ```

2. **Test connectivity using psql (from authorized network):**
   ```bash
   # Test original database
   psql -h your-original-endpoint \
        -U pgadmin4f612367 \
        -d postgres \
        -p 5432 \
        -c "SELECT 'ORIGINAL DATABASE' as db_type, version(), now();"

   # Test restored database
   psql -h your-restored-endpoint \
        -U pgadmin4f612367 \
        -d postgres \
        -p 5432 \
        -c "SELECT 'RESTORED DATABASE' as db_type, version(), now();"
   ```

3. **Port connectivity test (from same VPC):**
   ```bash
   # Test if port 5432 is accessible
   nc -z your-db-endpoint 5432 && echo "PostgreSQL port is accessible" || echo "Port not accessible"
   ```

### Method 2: Data Integrity Verification

1. **Compare database structures:**
   ```sql
   -- Connect to both databases and run:
   \l                          -- List all databases
   \dn                         -- List all schemas  
   \dt                         -- List all tables in current database
   \du                         -- List all users

   -- Check database sizes
   SELECT pg_database_size('postgres');

   -- Compare table row counts
   SELECT 
     schemaname,
     tablename, 
     n_tup_ins as inserts,
     n_tup_upd as updates, 
     n_tup_del as deletes
   FROM pg_stat_user_tables;
   ```

2. **System catalog comparison:**
   ```sql
   -- Compare system objects
   SELECT 'pg_class' as table_name, count(*) FROM pg_class
   UNION ALL
   SELECT 'pg_attribute', count(*) FROM pg_attribute
   UNION ALL  
   SELECT 'pg_proc', count(*) FROM pg_proc;
   ```

### Method 3: Comprehensive Connection Test Script

```bash
#!/bin/bash
# postgres_restore_test.sh

ORIGINAL_DB="your-original-endpoint"
RESTORED_DB="your-restored-endpoint" 
USERNAME="pgadmin4f612367"
DATABASE="postgres"
PORT="5432"

echo "=== PostgreSQL Restoration Verification ==="

# Test original database
echo "Testing original database connection..."
psql -h $ORIGINAL_DB -U $USERNAME -d $DATABASE -p $PORT \
     -c "SELECT 'Original DB' as source, version() as pg_version, now() as test_time;" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Original database: CONNECTION SUCCESS"
else
    echo "❌ Original database: CONNECTION FAILED"
fi

# Test restored database
echo "Testing restored database connection..."
psql -h $RESTORED_DB -U $USERNAME -d $DATABASE -p $PORT \
     -c "SELECT 'Restored DB' as source, version() as pg_version, now() as test_time;" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Restored database: CONNECTION SUCCESS"
    
    # Data integrity check
    echo "Performing data integrity check..."
    psql -h $RESTORED_DB -U $USERNAME -d $DATABASE -p $PORT \
         -c "SELECT count(*) as system_tables FROM pg_tables WHERE schemaname = 'pg_catalog';" 2>/dev/null
         
else
    echo "❌ Restored database: CONNECTION FAILED"
fi

echo "=== Test Complete ==="
```

---

## Debugging and Troubleshooting

### Common Configuration Errors

#### Error 1: "Invalid snapshot identifier"
**Symptom:** Terraform fails with invalid snapshot identifier error

**Cause:** Using instance identifier instead of snapshot identifier

**Solution:** 
```bash
# ❌ Wrong: Using instance identifier
Source DB Instance Identifier: test-pg-rds-test-datastore-1155708878-dev-aws

# ✅ Correct: Using snapshot identifier  
Source DB Instance Identifier: test-pg-rds-snapshot-for-restore-20250908-114851
```

#### Error 2: "Snapshot not found"
**Symptom:** Cannot find the specified snapshot

**Debugging steps:**
```bash
# List all available snapshots
aws rds describe-db-snapshots \
  --query "DBSnapshots[*].[DBSnapshotIdentifier, Status, DBInstanceIdentifier]" \
  --output table

# Check specific snapshot status
aws rds describe-db-snapshots \
  --db-snapshot-identifier your-snapshot-id \
  --query "DBSnapshots[0].[DBSnapshotIdentifier, Status, PercentProgress]" \
  --output json
```

#### Error 3: "Authentication failure after restoration"
**Symptom:** Cannot connect to restored database with provided credentials

**Solution:**
1. Wait for credential reset events to complete
2. Verify you're using the exact username from the original database
3. Check RDS events for "Reset master credentials" completion

### Debugging Commands

1. **Check deployment status:**
   ```bash
   aws rds describe-db-instances \
     --db-instance-identifier your-new-db \
     --query "DBInstances[0].[DBInstanceStatus, PendingModifiedValues]" \
     --output json
   ```

2. **Monitor all events:**
   ```bash
   aws rds describe-events \
     --source-type db-instance \
     --source-identifier your-new-db \
     --max-items 20 \
     --output table
   ```

3. **Check CloudWatch logs:**
   ```bash
   aws logs describe-log-groups \
     --log-group-name-prefix "/aws/rds/instance/your-new-db" \
     --output table
   ```

### Validation Checklist

**Pre-Deployment:**
- [ ] Snapshot is in "available" status
- [ ] Correct snapshot identifier is used (not instance identifier)  
- [ ] Master username matches source database
- [ ] Master password is correct

**During Deployment:**
- [ ] Instance status progresses: creating → modifying → available
- [ ] RDS events show snapshot restoration message
- [ ] No error events in RDS event log

**Post-Deployment:**
- [ ] Instance status is "available" 
- [ ] Database is accessible with original credentials
- [ ] Data integrity checks pass
- [ ] Performance metrics are normal

---

## Common Issues and Solutions

### Issue 1: Connection Timeouts
**Symptoms:** Cannot connect to restored database

**Solutions:**
1. **Check security groups:** Ensure PostgreSQL port 5432 is open
2. **Verify network connectivity:** Use jump host in same VPC if needed
3. **Wait for full initialization:** Allow 5-10 minutes after "available" status

### Issue 2: Different Master Username  
**Symptoms:** Username doesn't match expectations

**Root cause:** Random username generation was used instead of snapshot credentials

**Solution:** Ensure restore configuration uses snapshot credentials properly

### Issue 3: Performance Issues
**Symptoms:** Restored database is slower than original

**Solutions:**
1. **Allow warmup time:** Database buffers need time to populate
2. **Check instance class:** Verify same performance tier as original
3. **Monitor CloudWatch:** Compare metrics between instances

### Issue 4: Missing Data
**Symptoms:** Some data appears missing in restored instance

**Solutions:**
1. **Check snapshot timestamp:** Ensure snapshot captured all required data
2. **Verify restore point:** Confirm restoration used correct snapshot
3. **Check application timing:** Ensure no data was added after snapshot creation

---

## Best Practices

### Snapshot Management
1. **Create descriptive snapshot names** with timestamps
2. **Document snapshot contents** and creation context  
3. **Clean up old snapshots** to manage costs
4. **Test snapshots** in non-production environments first

### Restoration Planning
1. **Plan for restoration time** (20-30 minutes typical)
2. **Coordinate with applications** that use the database
3. **Have rollback plan** ready if issues occur
4. **Monitor throughout process** using AWS CLI and events

### Security Considerations
1. **Keep databases private** (no public access)
2. **Use appropriate security groups** 
3. **Maintain encryption** settings from original
4. **Rotate passwords** if needed after restoration

### Post-Restoration
1. **Comprehensive testing** before production use
2. **Performance monitoring** for several hours
3. **Update application configurations** as needed
4. **Document restoration process** and outcomes

---

## Success Indicators

### Definitive Proof of Successful Restoration

**✅ AWS RDS Events Show:**
```
"Restored from snapshot your-specific-snapshot-identifier"
```

**✅ Configuration Match:**
- Master username identical
- PostgreSQL version identical  
- Storage and instance class identical
- Security settings preserved

**✅ Connectivity Success:**
- Database accessible with original credentials
- All expected databases and tables present
- Data integrity checks pass

**✅ Timeline Verification:**
- Snapshot created before instance
- Instance creation follows logical sequence
- All deployment events completed successfully

---

## Conclusion

This guide provides a complete, tested workflow for PostgreSQL RDS snapshot restoration using the Facets control plane. The key success factors demonstrated through real-world implementation are:

1. **Proper snapshot creation** with descriptive naming
2. **Correct configuration** using snapshot ID (not instance ID)
3. **Comprehensive monitoring** throughout the restoration process
4. **Thorough verification** of restoration success
5. **Complete testing** of connectivity and data integrity

The restoration process is reliable when following these documented steps, with typical completion in 20-30 minutes and full data preservation from the snapshot creation point.

---

## Appendix: Command Quick Reference

### Snapshot Operations
```bash
# Create snapshot
aws rds create-db-snapshot --db-instance-identifier SOURCE_ID --db-snapshot-identifier SNAPSHOT_NAME

# Check snapshot status  
aws rds describe-db-snapshots --db-snapshot-identifier SNAPSHOT_NAME

# List all snapshots
aws rds describe-db-snapshots --output table
```

### Instance Monitoring
```bash
# Check instance status
aws rds describe-db-instances --query "DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Engine]" --output table

# Monitor events
aws rds describe-events --source-type db-instance --source-identifier INSTANCE_ID --output table

# Get connection details
aws rds describe-db-instances --db-instance-identifier INSTANCE_ID --query "DBInstances[0].[Endpoint.Address,Port,MasterUsername]" --output json
```

### PostgreSQL Testing
```bash
# Basic connection test
psql -h ENDPOINT -U USERNAME -d DATABASE -p 5432 -c "SELECT version(), now();"

# Data integrity check
psql -h ENDPOINT -U USERNAME -d DATABASE -p 5432 -c "SELECT count(*) FROM pg_tables;"

# Port connectivity
nc -z ENDPOINT 5432 && echo "Port accessible" || echo "Port not accessible"
```

---

*Guide based on real restoration session: September 8, 2025*
*PostgreSQL Version: 15.7 | Instance: test-pg-rds → test-pg-rds-new*
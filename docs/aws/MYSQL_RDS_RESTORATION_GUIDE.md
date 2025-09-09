# RDS Database Restoration Guide

## Overview
This guide provides a comprehensive walkthrough for restoring an AWS RDS MySQL database using the Facets control plane. This process creates a point-in-time restore of an existing database to a new instance.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Understanding the Restoration Process](#understanding-the-restoration-process)
3. [Step-by-Step Instructions](#step-by-step-instructions)
4. [Debugging and Troubleshooting](#debugging-and-troubleshooting)
5. [Testing and Verification](#testing-and-verification)
6. [Connectivity Testing](#connectivity-testing)
7. [Common Issues and Solutions](#common-issues-and-solutions)

---

## Prerequisites

### Required Access
- AWS CLI configured with appropriate permissions
- Access to Facets control plane
- RDS instance management permissions

### Required Information
- Source database instance identifier
- Source database master password
- VPC and security group details

### Tools Needed
- AWS CLI
- MySQL client (for connectivity testing)
- `nc` (netcat) for port testing

---

## Understanding the Restoration Process

### What Happens During Restoration
The Facets aws-rds module uses **Point-in-Time Restore** functionality, which:

1. **Creates a new RDS instance** from the source database
2. **Restores data** to the latest available point-in-time (not from manual snapshots)
3. **Maintains all configurations** from the source instance
4. **Uses `restore_to_point_in_time` Terraform resource** with `use_latest_restorable_time = true`

### Key Files in aws-rds Module
```
datastore/mysql/aws-rds/1.0/
├── facets.yaml     # Configuration schema
├── main.tf         # Terraform resources (includes restore logic)
├── locals.tf       # Local variables and restore conditions
├── variables.tf    # Input variables
└── outputs.tf      # Output definitions
```

### Restore Logic
```hcl
# From main.tf (lines 165-168)
restore_to_point_in_time {
  source_db_instance_identifier = var.instance.spec.restore_config.source_db_instance_identifier
  use_latest_restorable_time    = true
}
```

---

## Step-by-Step Instructions

### Phase 1: Identify Source Database

1. **List existing RDS instances:**
   ```bash
   aws rds describe-db-instances \
     --query "DBInstances[?contains(DBInstanceIdentifier, 'your-db-name')].[DBInstanceIdentifier,DBInstanceStatus,Engine,EngineVersion]" \
     --output table
   ```

2. **Get source database details:**
   ```bash
   aws rds describe-db-instances \
     --db-instance-identifier your-source-db-identifier \
     --query "DBInstances[0].[DBSubnetGroup.DBSubnetGroupName,VpcSecurityGroups[0].VpcSecurityGroupId]" \
     --output table
   ```

3. **Record the following information:**
   - DB Instance Identifier
   - DB Subnet Group Name  
   - Security Group ID
   - Master username and password

### Phase 2: Configure Restoration in Control Plane

1. **Navigate to your target resource** in the Facets control plane (e.g., `test-rds-db-new`)

2. **Enable restoration** by checking:
   - ☑️ **Restore from Backup**: `true`

3. **Configure restoration fields:**
   ```yaml
   Restore from Backup Section:
   - Source DB Instance: [source-db-instance-identifier]
   - Restore Master Username: [master-username] 
   - Restore Master Password: [master-password]
   
   Import Existing Resources Section:
   - DB Instance Identifier: [source-db-instance-identifier]
   - DB Subnet Group Name: [subnet-group-name]
   - Security Group ID: [security-group-id]
   ```

4. **Example configuration:**
   ```yaml
   Source DB Instance: test-rds-db-test-datastore-1155708878-dev-aws
   Restore Master Username: admin
   Restore Master Password: 3)OHycI?l]pqlIhW
   DB Instance Identifier: test-rds-db-test-datastore-1155708878-dev-aws
   DB Subnet Group Name: test-rds-db-test-datastore-1155708878-dev-aws-subnet-group
   Security Group ID: sg-03635ba9ada14777d
   ```

### Phase 3: Deploy and Monitor

1. **Deploy the resource** through the control plane

2. **Monitor deployment progress:**
   ```bash
   aws rds describe-db-instances \
     --db-instance-identifier your-new-db-identifier \
     --query "DBInstances[0].[DBInstanceStatus,PercentProgress]" \
     --output table
   ```

3. **Wait for "available" status** (typically 10-20 minutes)

---

## Debugging and Troubleshooting

### Common Errors and Solutions

#### Error: "DBInstanceNotFound"
**Symptom:** 
```
operation error RDS: RestoreDBInstanceToPointInTime, 
DBInstanceNotFound: The source instance could not be found
```

**Cause:** Using snapshot identifier instead of instance identifier

**Solution:** 
- Use the actual DB instance identifier (e.g., `test-rds-db-source`)
- NOT the snapshot identifier (e.g., `test-rds-db-snapshot-123`)

#### Error: "InvalidParameterValue"
**Symptom:** Invalid parameter combinations or missing required fields

**Solution:**
1. Verify all required fields are filled
2. Ensure master username follows pattern: `^[a-zA-Z][a-zA-Z0-9_]*$`
3. Ensure master password meets length requirements (8-128 characters)

#### Error: "InsufficientDBInstanceCapacity"
**Symptom:** Cannot create instance in specified availability zone

**Solution:**
1. Check if the instance class is available in your region
2. Try a different instance class (e.g., db.t3.small instead of db.t3.micro)
3. Contact AWS support for capacity issues

### Debugging Commands

1. **Check deployment events:**
   ```bash
   aws rds describe-events \
     --source-type db-instance \
     --source-identifier your-new-db-identifier \
     --start-time 2025-09-05T08:00:00.000Z \
     --output table
   ```

2. **Monitor CloudWatch logs:**
   ```bash
   aws logs describe-log-groups \
     --log-group-name-prefix "/aws/rds/instance/your-new-db" \
     --output table
   ```

3. **Check restore progress:**
   ```bash
   aws rds describe-db-instances \
     --db-instance-identifier your-new-db-identifier \
     --query "DBInstances[0].[RestoreTime,LatestRestorableTime,BackupRetentionPeriod]" \
     --output table
   ```

---

## Testing and Verification

### Verification Checklist

#### ✅ **Instance Status Verification**
```bash
aws rds describe-db-instances \
  --query "DBInstances[?contains(DBInstanceIdentifier, 'your-db')].[DBInstanceIdentifier,DBInstanceStatus,Engine,EngineVersion]" \
  --output table
```
**Expected:** Both instances show "available" status

#### ✅ **Configuration Comparison**
```bash
aws rds describe-db-instances \
  --query "DBInstances[?contains(DBInstanceIdentifier, 'your-db')].[DBInstanceIdentifier,EngineVersion,MasterUsername,AllocatedStorage,StorageType,MultiAZ,BackupRetentionPeriod,StorageEncrypted]" \
  --output table
```
**Expected:** Identical configurations between source and restored instances

#### ✅ **Restoration Events Verification**
```bash
aws rds describe-events \
  --source-type db-instance \
  --source-identifier your-new-db-identifier \
  --query "Events[*].[Date,Message]" \
  --output table
```
**Expected Events:**
- "Restored from DB instance [source] to [timestamp]"
- "Finished applying modification to convert to a Multi-AZ DB Instance"
- "Reset master credentials"
- "Finished DB Instance backup"

#### ✅ **Network Configuration Verification**
```bash
aws rds describe-db-instances \
  --query "DBInstances[?contains(DBInstanceIdentifier, 'your-db')].[DBInstanceIdentifier,PubliclyAccessible,VpcSecurityGroups[0].VpcSecurityGroupId,DBSubnetGroup.VpcId]" \
  --output table
```
**Expected:** 
- PubliclyAccessible: False (for security)
- Same VPC ID for both instances
- Appropriate security groups assigned

### Success Indicators

1. **AWS RDS Events Show:** 
   ```
   "Restored from DB instance [source] to [timestamp]"
   ```

2. **Instance Status:** `available`

3. **Configuration Match:** All critical settings identical

4. **Logs Available:** CloudWatch logs accessible and populated

5. **Network Isolation:** Properly configured as private instances

---

## Connectivity Testing

### Prerequisites for Testing
Since RDS instances are typically in private subnets, direct connectivity testing requires:

1. **EC2 instance in same VPC** (jump host/bastion)
2. **VPN connection** to the VPC
3. **Modified security groups** (temporarily for testing)

### Method 1: Using EC2 Jump Host

1. **Launch EC2 instance** in same VPC and subnet
2. **Install MySQL client:**
   ```bash
   # On Amazon Linux/CentOS
   sudo yum install mysql -y
   
   # On Ubuntu/Debian  
   sudo apt update && sudo apt install mysql-client -y
   ```

3. **Test connectivity to original database:**
   ```bash
   mysql -h your-original-db-endpoint \
         -u admin \
         -p'your-password' \
         -e "SELECT 'ORIGINAL DATABASE' as db_type, VERSION() as version, NOW() as current_time;"
   ```

4. **Test connectivity to restored database:**
   ```bash
   mysql -h your-restored-db-endpoint \
         -u admin \
         -p'your-password' \
         -e "SELECT 'RESTORED DATABASE' as db_type, VERSION() as version, NOW() as current_time;"
   ```

### Method 2: Port Connectivity Testing

1. **Test port accessibility:**
   ```bash
   # From jump host
   nc -z -w 5 your-db-endpoint 3306 && echo "Port 3306 is open" || echo "Port 3306 is not accessible"
   ```

2. **Test with timeout:**
   ```bash
   timeout 10 nc -z your-db-endpoint 3306 && echo "Connection successful" || echo "Connection failed"
   ```

### Method 3: Database Schema Comparison

1. **Compare database list:**
   ```sql
   -- Connect to both instances and run:
   SHOW DATABASES;
   ```

2. **Compare table structures:**
   ```sql
   -- For each database:
   USE your_database_name;
   SHOW TABLES;
   
   -- For specific table:
   DESCRIBE your_table_name;
   ```

3. **Compare row counts:**
   ```sql
   SELECT 
       TABLE_SCHEMA as database_name,
       TABLE_NAME as table_name,
       TABLE_ROWS as estimated_rows
   FROM information_schema.TABLES 
   WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys');
   ```

### Method 4: Application-Level Testing

1. **Update application configuration** to point to restored database
2. **Run application health checks**
3. **Verify data consistency** through application queries
4. **Test write operations** (if safe to do so)

### Connectivity Verification Script

```bash
#!/bin/bash
# connectivity_test.sh

DB_ORIGINAL="your-original-db-endpoint"
DB_RESTORED="your-restored-db-endpoint"
USERNAME="admin"
PASSWORD="your-password"

echo "=== Database Connectivity Test ==="

# Test original database
echo "Testing original database..."
mysql -h $DB_ORIGINAL -u $USERNAME -p$PASSWORD -e "SELECT 'Original DB Online' as status, VERSION() as version;" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Original database: CONNECTED"
else
    echo "❌ Original database: CONNECTION FAILED"
fi

# Test restored database  
echo "Testing restored database..."
mysql -h $DB_RESTORED -u $USERNAME -p$PASSWORD -e "SELECT 'Restored DB Online' as status, VERSION() as version;" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Restored database: CONNECTED"
else
    echo "❌ Restored database: CONNECTION FAILED"
fi

echo "=== Test Complete ==="
```

---

## Common Issues and Solutions

### Issue 1: Connection Timeouts
**Symptoms:** Cannot connect to database, timeouts

**Solutions:**
1. **Check security groups:** Ensure port 3306 is open from your source IP
2. **Verify network ACLs:** Check subnet-level restrictions
3. **Confirm VPC routing:** Ensure proper route tables
4. **Use jump host:** Connect through EC2 instance in same VPC

### Issue 2: Authentication Failures
**Symptoms:** "Access denied for user" errors

**Solutions:**
1. **Verify password:** Ensure correct master password is used
2. **Check username:** Confirm master username (typically 'admin')
3. **Wait for credential reset:** Check RDS events for "Reset master credentials" completion

### Issue 3: Data Inconsistencies
**Symptoms:** Missing or outdated data in restored instance

**Solutions:**
1. **Check restore point:** Verify the restoration timestamp in RDS events
2. **Understand point-in-time:** Data restored to latest available point, not necessarily current
3. **Check source activity:** Ensure source database was active during restore period

### Issue 4: Performance Differences
**Symptoms:** Restored database performs differently

**Solutions:**
1. **Allow warmup time:** Database cache needs time to populate
2. **Check instance class:** Ensure same performance tier as source
3. **Monitor CloudWatch metrics:** Compare CPU, IOPS, connections
4. **Analyze slow query logs:** Check for performance regressions

---

## Best Practices

### Before Restoration
1. **Document source configuration** thoroughly
2. **Test restoration process** in development environment first
3. **Plan for downtime** if switching applications
4. **Backup current state** before making changes

### During Restoration
1. **Monitor AWS RDS events** continuously
2. **Check CloudWatch metrics** for anomalies
3. **Avoid modifying source database** during restoration
4. **Keep restoration logs** for troubleshooting

### After Restoration
1. **Verify data integrity** thoroughly
2. **Update application configurations** if needed
3. **Monitor performance metrics** for several hours
4. **Document lessons learned** for future restorations

### Security Considerations
1. **Keep databases private** (PubliclyAccessible = false)
2. **Use appropriate security groups** with minimal access
3. **Enable encryption** in transit and at rest
4. **Rotate passwords** after restoration if needed
5. **Monitor access logs** for unauthorized attempts

---

## Conclusion

This guide provides a complete workflow for restoring AWS RDS MySQL databases using the Facets control plane. The key success factors are:

1. **Understanding the point-in-time restore mechanism**
2. **Proper configuration of restoration parameters**
3. **Comprehensive testing and verification**
4. **Appropriate connectivity testing methods**

Remember that database restoration is a critical operation that should always be tested thoroughly in non-production environments before implementing in production systems.

---

## Appendix: Command Reference

### AWS CLI Commands
```bash
# List RDS instances
aws rds describe-db-instances --output table

# Get specific instance details
aws rds describe-db-instances --db-instance-identifier INSTANCE_ID

# Monitor events
aws rds describe-events --source-type db-instance --source-identifier INSTANCE_ID

# Check logs
aws logs describe-log-groups --log-group-name-prefix "/aws/rds/instance/"
```

### MySQL Commands
```sql
-- Basic connectivity test
SELECT VERSION(), NOW();

-- Database comparison
SHOW DATABASES;
USE database_name;
SHOW TABLES;

-- Data verification
SELECT COUNT(*) FROM table_name;
DESCRIBE table_name;
```

### Networking Commands
```bash
# Port testing
nc -z -w 5 hostname 3306

# DNS resolution
nslookup your-db-endpoint

# Network path testing
traceroute your-db-endpoint
```

---

*Last updated: September 5, 2025*
*Version: 1.0*
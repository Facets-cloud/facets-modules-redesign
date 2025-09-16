# PostgreSQL RDS Module

![Version](https://img.shields.io/badge/version-1.0-blue) ![Cloud](https://img.shields.io/badge/cloud-AWS-orange)

## Overview

This module provisions a managed PostgreSQL database using Amazon RDS with enterprise-grade security defaults and operational best practices. It provides a developer-friendly interface while maintaining production-ready configurations for encryption, backup, and high availability.

## Environment as Dimension

This module is environment-aware and adapts configurations based on the deployment environment:

- **Resource Naming**: Incorporates `var.environment.unique_name` to ensure unique resource identifiers across environments
- **Tagging Strategy**: Applies environment-specific tags via `var.environment.cloud_tags` for consistent resource organization
- **Network Isolation**: Deploys within environment-specific VPC infrastructure provided through inputs

Environment-specific variations are handled through the infrastructure inputs rather than direct environment variables, maintaining consistency while allowing environment-appropriate networking and access controls.

## Resources Created

- **RDS PostgreSQL Instance** - Primary database instance with multi-AZ deployment for high availability
- **Read Replicas** - Optional read-only replicas for improved read performance and load distribution
- **DB Subnet Group** - Private subnet configuration ensuring database isolation from public networks  
- **Security Group** - Restrictive network access controls allowing database connections only from within the VPC
- **Random Credentials** - Secure master username and password generation when not restoring from backup

## Security Considerations

This module implements security-first defaults that cannot be disabled:

- **Encryption at Rest**: All database storage is encrypted using AWS-managed keys
- **Network Isolation**: Database instances are deployed in private subnets with no public access
- **Access Controls**: Security groups restrict database access to VPC CIDR blocks only
- **Backup Security**: Automated backups with 7-day retention and encrypted snapshots
- **Deletion Protection**: Prevents accidental database deletion in production environments
- **Performance Monitoring**: Performance Insights enabled for security event monitoring

Users should ensure proper IAM policies and VPC configurations are in place to maintain the security posture established by this module.

## Import Existing Infrastructure

This module supports importing existing AWS RDS PostgreSQL instances and their associated resources into Terraform management.

### Supported Import Resources

- **RDS Instance**: Import existing primary or read replica instances
- **DB Subnet Group**: Import existing subnet group configurations
- **Security Group**: Import existing security group rules

### Import Configuration

To import existing resources, provide the following fields in the `imports` section:

```yaml
spec:
  imports:
    db_instance_identifier: "my-existing-rds-instance"
    subnet_group_name: "my-existing-subnet-group"
    security_group_id: "sg-0123456789abcdef0"
```

### Import Workflow

1. **Configure Import Fields**: Set the appropriate identifiers in the module configuration
2. **Run Terraform Import**: Execute import commands for each resource:
   ```bash
   terraform import module.postgres.aws_db_instance.postgres my-existing-rds-instance
   terraform import module.postgres.aws_db_subnet_group.postgres[0] my-existing-subnet-group
   terraform import module.postgres.aws_security_group.postgres[0] sg-0123456789abcdef0
   ```
3. **Verify State**: Run `terraform plan` to ensure imported resources match configuration

### Important Limitations

#### Read Replica Handling

When importing a primary instance that has existing read replicas:

- **Only the primary instance is imported** into Terraform state
- **Pre-existing read replicas remain unmanaged** by Terraform
- **New read replicas** are created based on `read_replica_count` configuration with an `-imp` suffix to avoid naming conflicts
- **Existing unmanaged replicas** continue to exist in AWS but outside Terraform control
- **Example**: If existing replica is `mydb-env-replica-1`, new Terraform-managed replica will be `mydb-env-imp-replica-1`
- **Identifier length**: Automatically truncated to stay within AWS 63-character limit, avoiding consecutive hyphens

#### Destroy Behavior with Existing Replicas

**Critical**: If you import a primary instance that has pre-existing read replicas and later attempt to destroy it:

1. **Terraform-managed resources** (new replicas, security groups) will be destroyed successfully
2. **Primary instance deletion will FAIL** with an error like:
   - `InvalidDBInstanceState: Cannot delete DB instance because it has read replicas`
   - AWS prevents deletion of primary instances with active read replicas

#### Recommended Destroy Workflow

Before running `terraform destroy` on an imported primary instance:

1. **Identify unmanaged replicas** using AWS Console or CLI:
   ```bash
   aws rds describe-db-instances --query "DBInstances[?ReplicationSourceDBInstanceIdentifier=='your-primary-instance-id'].DBInstanceIdentifier"
   ```

2. **Handle existing replicas** (choose one):
   - **Option A**: Manually delete unmanaged replicas first
   - **Option B**: Promote replicas to standalone instances
   - **Option C**: Use AWS Console to force-delete primary (promotes replicas automatically)

3. **Run Terraform destroy** after handling unmanaged replicas

#### Password Management for Imported Instances

- **Passwords are not retrievable** from imported instances
- **Connection strings** in outputs will not include passwords for imported resources
- **Manual password management** required for imported instances
- **Password field** shows placeholder: `IMPORTED_INSTANCE_PASSWORD_NOT_AVAILABLE`

### Best Practices for Import

1. **Import one instance at a time** - Either primary or a single replica
2. **Document existing replicas** before import for future reference
3. **Test destroy workflow** in non-production first
4. **Consider migration strategy** for existing replicas:
   - Keep them unmanaged for gradual migration
   - Or recreate them as Terraform-managed resources
5. **Enable deletion protection** to prevent accidental deletion of imported instances

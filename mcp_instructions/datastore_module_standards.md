# Datastore Module Standards

These instructions supplement the default Facets module generation guidelines for this repository.

## Repository Scope

This repository contains modules for databases, caches, queues, and their various flavors. Each module represents a specific technology (e.g., `postgres`, `redis`, `rabbitmq`).

## Design Philosophy

### Simplicity Over Flexibility
- Provide the most common functionalities
- Do NOT expose every possible configuration option
- Users can fork the repository for custom configurations

### Technology-Familiar Field Names
- Use field names familiar to users of the underlying technology
- Do NOT invent new abstractions or terms
- Group fields logically by sections for better organization
- Make modules configurable by developers who are not always cloud experts
- Do NOT expose low-level cloud details that can be derived or generated (e.g., subnet groups, security groups, credentials)
- Generate necessary infrastructure components within the module

### Security-First Defaults
- Always configure secure defaults
- Enable encryption by default where available
- Follow principle of least privilege for access

## Module Conventions

### Naming Standards
- **Intent**: Use only the technology name (e.g., `postgres`, `redis`, `kafka`)
- **Flavors**: Represent variants or configurations (e.g., `ha`, `secure`, `basic`)
- **Name Length Limits**: Ensure generated resource names comply with cloud provider and Kubernetes naming constraints (typically 63 characters max)

### Output Namespace Requirement
- **All module outputs MUST use `@facets/` namespace**
- **All module inputs can ONLY consume `@facets/` namespaced outputs**
- Examples: `@facets/postgres`, `@facets/redis-cluster`, `@facets/kafka-topic`

## Core Functionality Requirements

Every module in this repository MUST provide support for:

1. **Version Management**
   - **Support only the last 3 major versions** of each technology
   - **Do NOT support deprecated versions** or technologies
   - Version specification and upgrade paths
   - Automated or manual version updates

2. **Authentication**
   - Secure credential management
   - Access control configuration
   - Integration with identity providers where applicable

3. **Sizing**
   - Performance-based instance sizing
   - Storage capacity configuration
   - Resource scaling options

4. **Backup & Restore**
   - Automated backup configuration
   - Point-in-time recovery options
   - Backup retention policies

5. **Import Support**
   - MUST support importing existing resources
   - Include import declarations in facets.yaml
   - Use `discover_terraform_resources()` to identify importable resources
   - Use `add_import_declaration()` to configure imports

## Required Module Structure

```
technology-name/
├── facets.yaml          # Must include @facets/ outputs and import declarations
├── main.tf             # Core Terraform resources
├── variables.tf        # Must mirror facets.yaml spec structure
├── locals.tf           # Local computations and output_attributes
└── README.md           # Generated documentation
```

## Import Configuration Requirements

Every module MUST include import declarations in facets.yaml:

```yaml
imports:
  - name: primary_resource
    resource_address: <resource_type>.<resource_name>
    required: true
```

Use the import tools to discover and configure importable resources:
1. Run `discover_terraform_resources(module_path)` to identify resources
2. Add import declarations for primary resources
3. Include backup, monitoring, and security resources where applicable

## Standardized Output Structure

All modules of the same intent MUST maintain consistency in their `interfaces` output structure.

### Reader/Writer Datastores
For datastores that offer reader/writer separation:

```yaml
# In locals.tf - output_interfaces
output_interfaces = {
  writer = {
    host = "<writer_endpoint>"
    username = "<username>"
    password = "<password>"
    connection_string = "<protocol>://<username>:<password>@<writer_endpoint>:<port>/<database>"
  }
  reader = {
    host = "<reader_endpoint>"
    username = "<username>"
    password = "<password>"  
    connection_string = "<protocol>://<username>:<password>@<reader_endpoint>:<port>/<database>"
  }
}
```

### Clustered Datastores  
For clustered setups:

```yaml
# In locals.tf - output_interfaces
output_interfaces = {
  cluster = {
    endpoint = "<host1>:<port>,<host2>:<port>,<host3>:<port>"
    connection_string = "<protocol>://<username>:<password>@<host1>:<port>,<host2>:<port>/<database>"
    username = "<username>"
    password = "<password>"
    endpoints = {
      "0" = "<host1>:<port>"
      "1" = "<host2>:<port>"
      "2" = "<host3>:<port>"
    }
  }
}
```

### Connection String Format
- **Protocol-prefixed**: Use technology-specific prefix (e.g., `mysql://`, `postgres://`, `redis://`)
- **Driver-agnostic**: No JDBC or other driver-specific prefixes
- **Standard format**: `<protocol>://<username>:<password>@<host>:<port>/<database>`

## Standardized Spec Section Structure

All modules MUST organize their `spec.properties` in the following order:

### 1. Version & Basic Configuration
```yaml
spec:
  properties:
    version:
      type: string
      title: "Database Version"
      description: "Version of the database engine"
      enum: ["13", "14", "15"]  # Only last 3 major versions, no deprecated versions
      default: "15"  # Always default to latest supported version
```

### 2. Instance Configuration
```yaml
    instance_class:
      type: string
      title: "Instance Class"
      description: "Database instance class"
      enum: ["db.t3.micro", "db.t3.small", "db.t3.medium", "db.m5.large"]
      default: "db.t3.small"
    
    allocated_storage:
      type: number
      title: "Allocated Storage (GB)"
      description: "Initial storage allocation in GB"
      minimum: 20
      default: 100
```

### 3. High Availability & Clustering
```yaml
    multi_az:
      type: boolean
      title: "Multi-AZ Deployment"
      description: "Enable multi-availability zone deployment"
      default: false
    
    read_replica_count:
      type: number
      title: "Read Replica Count" 
      description: "Number of read replicas to create"
      minimum: 0
      maximum: 5
      default: 0
```

### 4. Authentication & Security
```yaml
    storage_encrypted:
      type: boolean
      title: "Storage Encryption"
      description: "Enable encryption at rest"
      default: true
    
    # Note: master_username and password should be generated within the module
    # Do not expose credentials as configurable fields
```

### 5. Backup & Maintenance
```yaml
    backup_retention_period:
      type: number
      title: "Backup Retention Period (Days)"
      description: "Number of days to retain automated backups"
      minimum: 1
      maximum: 35
      default: 7
    
    preferred_maintenance_window:
      type: string
      title: "Preferred Maintenance Window"
      description: "Preferred maintenance window (UTC)"
      default: "sun:03:00-sun:04:00"
```

### 6. Networking & Access
```yaml
    publicly_accessible:
      type: boolean
      title: "Publicly Accessible"
      description: "Enable public accessibility"
      default: false
    
    # Note: subnet groups, security groups, and other networking components
    # should be derived from VPC inputs or created within the module
    # Do not expose low-level networking configuration
```

## Validation Checklist

Before completing any module:
- [ ] Generated resource names comply with cloud provider and Kubernetes length limits (63 chars)
- [ ] Only last 3 major versions supported, no deprecated versions
- [ ] Outputs use `@facets/` namespace
- [ ] Inputs only consume `@facets/` namespaced types
- [ ] Import declarations included for all major resources
- [ ] Core functionality (version, auth, sizing, backup) implemented
- [ ] Security defaults configured
- [ ] Standardized interfaces output structure implemented
- [ ] Spec sections follow standard order and naming
- [ ] Module validates successfully with `validate_module()`
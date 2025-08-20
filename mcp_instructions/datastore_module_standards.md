# Datastore Module Standards

These instructions supplement the default Facets module generation guidelines for this repository.

## Repository Scope

This repository contains modules for databases, caches, queues, and their various flavors. Each module represents a specific technology (e.g., `postgres`, `redis`, `rabbitmq`).

## Design Philosophy

### Simplicity Over Flexibility
- Provide the most common functionalities with sensible defaults
- Do NOT expose every possible configuration option
- Use secure, production-ready defaults that don't require configuration
- Users can fork the repository for custom configurations

### Technology-Familiar Field Names
- Use field names familiar to users of the underlying technology
- Do NOT invent new abstractions or terms
- Group fields logically by sections for better organization
- Make modules configurable by developers who are not always cloud experts
- Do NOT expose low-level cloud details that can be derived or generated (e.g., subnet groups, security groups, credentials)
- Generate necessary infrastructure components within the module

### Security-First Defaults
- Always configure secure, production-ready defaults
- Enable encryption at rest and in transit automatically (not configurable)
- Enable high availability by default (not configurable)
- Configure sensible backup policies automatically (not configurable)
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
   - Automated backup configuration with sensible defaults (not configurable)
   - **MUST support restore from backup functionality** - essential capability
   - Point-in-time recovery options

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

### 3. Backup & Restore
```yaml
    restore_from_backup:
      type: boolean
      title: "Restore from Backup"
      description: "Restore database from existing backup"
      default: false
    
    source_db_instance_identifier:
      type: string
      title: "Source DB Instance"
      description: "Source database instance identifier for restore"
      x-ui-visible-if:
        field: spec.restore_from_backup
        values: [true]
    
    # Note: Backup retention, encryption, HA are configured automatically
    # - Backup retention: 7 days (not configurable)
    # - Encryption: Always enabled (not configurable)
    # - Multi-AZ: Enabled by default (not configurable)
```

### 4. Optional Features
```yaml
    read_replica_count:
      type: number
      title: "Read Replica Count" 
      description: "Number of read replicas to create"
      minimum: 0
      maximum: 5
      default: 0
    
    # Note: Other features like monitoring, performance insights are 
    # enabled by default with sensible configurations (not exposed)
```

## Validation Checklist

Before completing any module:
- [ ] Generated resource names comply with cloud provider and Kubernetes length limits (63 chars)
- [ ] Only last 3 major versions supported, no deprecated versions
- [ ] Outputs use `@facets/` namespace
- [ ] Inputs only consume `@facets/` namespaced types
- [ ] Import declarations included for all major resources
- [ ] Restore from backup functionality implemented and tested
- [ ] Security defaults hardcoded (encryption always on, HA by default)
- [ ] Backup policies configured automatically with sensible defaults
- [ ] Credentials, subnet groups, security groups auto-generated
- [ ] Standardized interfaces output structure implemented
- [ ] Spec sections follow simplified structure (version, sizing, restore, optional features)
- [ ] Module validates successfully with `validate_module()`
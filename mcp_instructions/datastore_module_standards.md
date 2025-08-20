# Datastore Module Standards

These instructions supplement the default Facets module generation guidelines for this repository.

## Repository Scope

This repository contains modules for databases, caches, queues, and their various flavors. Each module represents a specific technology (e.g., `postgres`, `redis`, `rabbitmq`).

## Design Philosophy

### Simplicity Over Flexibility
- Provide the most common functionalities
- Do NOT expose every possible configuration option
- Users can fork the repository for custom configurations

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
    performance_tier:
      type: string
      title: "Performance Tier"
      description: "Performance level for the instance"
      enum: ["basic", "standard", "high", "premium"]
      default: "standard"
    
    storage_size:
      type: number
      title: "Storage Size (GB)"
      description: "Initial storage allocation in GB"
      minimum: 20
      default: 100
```

### 3. High Availability & Clustering
```yaml
    high_availability:
      type: boolean
      title: "Enable High Availability"
      description: "Enable multi-zone deployment for high availability"
      default: false
    
    read_replicas:
      type: number
      title: "Read Replica Count" 
      description: "Number of read replicas to create"
      minimum: 0
      maximum: 5
      default: 0
```

### 4. Authentication & Security
```yaml
    admin_username:
      type: string
      title: "Admin Username"
      description: "Administrator username for the database"
      default: "admin"
    
    enable_encryption:
      type: boolean
      title: "Enable Encryption"
      description: "Enable encryption at rest and in transit"
      default: true
```

### 5. Backup & Maintenance
```yaml
    backup_retention:
      type: number
      title: "Backup Retention (Days)"
      description: "Number of days to retain automated backups"
      minimum: 1
      maximum: 35
      default: 7
    
    maintenance_window:
      type: string
      title: "Maintenance Window"
      description: "Preferred maintenance window"
      enum: ["weeknight", "weekend", "custom"]
      default: "weeknight"
```

### 6. Networking & Access
```yaml
    public_access:
      type: boolean
      title: "Enable Public Access"
      description: "Allow connections from public internet"
      default: false
    
    allowed_cidrs:
      type: array
      title: "Allowed CIDR Blocks"
      description: "CIDR blocks allowed to connect"
      items:
        type: string
        pattern: "^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$"
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
# ╔═══════════════════════════════════════════════════════════╗
# ║ AUTO-GENERATED from facets.yaml — DO NOT EDIT            ║
# ║                                                          ║
# ║ Any changes will be overwritten on next mutation command. ║
# ╚═══════════════════════════════════════════════════════════╝

variable "instance" {
  type = object({
    kind = string
    spec = object({
      source_cidr = optional(string, "")
      rules = map(object({
        security_group_id = string
        port              = number
        cidr              = optional(string, null)
        description       = optional(string, null)
      }))
    })
  })
}

variable "instance_name" {
  type        = string
  description = "Resource name in the blueprint (architectural name, e.g. main-db, api)"
}

variable "environment" {
  type = object({
    name        = string                    # Environment name (e.g., dev, staging, prod)
    unique_name = string                    # Project + environment (globally unique, e.g., myapp-prod)
    cloud_tags  = optional(map(string), {}) # Cloud resource tags injected by Facets at deploy time
  })
  description = "Environment context. Use unique_name + instance_name for globally unique resource names."
}

variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = optional(object({
        aws_iam_role = optional(string)
        aws_region   = optional(string)
        external_id  = optional(string)
        session_name = optional(string)
      }))
      interfaces = optional(object({}))
    })
  })
}

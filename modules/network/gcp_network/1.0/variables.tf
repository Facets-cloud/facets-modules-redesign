variable "instance_name" {
  description = "Name of the instance"
  type        = string
}

variable "environment" {
  description = "Environment configuration"
  type = object({
    name         = string
    unique_name  = string
    cloud_tags   = map(string)
    cluster_code = optional(string, "")
  })
}

variable "inputs" {
  description = "Input references from other modules"
  type = object({
    cloud_account = object({
      attributes = optional(object({
        credentials = optional(string)
        project_id  = optional(string)
        region      = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}

variable "instance" {
  description = "Instance configuration"
  type        = any

  # VPC CIDR must be /16 for GKE-optimized allocation
  validation {
    condition     = try(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/16$", lookup(var.instance.spec, "vpc_cidr", "")), false) != false
    error_message = "VPC CIDR must be a /16 block (e.g., 10.0.0.0/16) for optimal GKE workloads."
  }


  # Validation for labels: ensure all label values are strings
  validation {
    condition = try(
      alltrue([
        for k, v in lookup(var.instance.spec, "labels", {}) : can(tostring(v))
      ]),
      true
    )
    error_message = "All label values must be strings."
  }

  # Validation for labels: ensure label keys don't conflict with reserved keys
  validation {
    condition = try(
      alltrue([
        for k in keys(lookup(var.instance.spec, "labels", {})) : !contains(["environment", "managed-by", "module", "project"], k)
      ]),
      true
    )
    error_message = "Label keys 'environment', 'managed-by', 'module', and 'project' are reserved and will be overridden by the module."
  }
}
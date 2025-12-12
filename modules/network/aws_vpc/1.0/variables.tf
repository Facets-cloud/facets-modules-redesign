variable "instance_name" {
  description = "Name of the instance"
  type        = string
}

variable "environment" {
  description = "Environment configuration"
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "Input references from other modules"
  type        = map(any)
  default     = {}
}

variable "instance" {
  description = "Instance configuration"
  type        = any

  # VPC CIDR must be /16 for K8s-optimized allocation
  validation {
    condition     = try(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/16$", lookup(var.instance.spec, "vpc_cidr", "")), false) != false
    error_message = "VPC CIDR must be a /16 block (e.g., 10.0.0.0/16) for optimal Kubernetes workloads."
  }

  # Availability zones validation when manually specified
  validation {
    condition = (
      lookup(var.instance.spec, "auto_select_azs", true) == true ||
      (
        length(lookup(var.instance.spec, "availability_zones", [])) >= 2 &&
        length(lookup(var.instance.spec, "availability_zones", [])) <= 5
      )
    )
    error_message = "When auto_select_azs is false, you must specify between 2 and 5 availability zones."
  }

  # AZ format validation
  validation {
    condition = (
      lookup(var.instance.spec, "auto_select_azs", true) == true ||
      length(lookup(var.instance.spec, "availability_zones", [])) == 0 ||
      alltrue([
        for az in lookup(var.instance.spec, "availability_zones", []) :
        can(regex("^[a-z]{2}-[a-z]+-[0-9][a-z]$", az))
      ])
    )
    error_message = "When specified, availability zones must be in format like 'us-east-1a'."
  }

  # NAT Gateway strategy validation
  validation {
    condition = try(
      contains(["single", "per_az"], var.instance.spec.nat_gateway.strategy),
      false
    )
    error_message = "NAT Gateway strategy must be either 'single' or 'per_az'."
  }

  # Validation for tags: ensure all tag values are strings
  validation {
    condition = try(
      alltrue([
        for k, v in lookup(var.instance.spec, "tags", {}) : can(tostring(v))
      ]),
      true
    )
    error_message = "All tag values must be strings."
  }

  # Validation for tags: ensure tag keys don't conflict with reserved keys
  validation {
    condition = try(
      alltrue([
        for k in keys(lookup(var.instance.spec, "tags", {})) : !contains(["Name", "Environment"], k)
      ]),
      true
    )
    error_message = "Tag keys 'Name' and 'Environment' are reserved and will be overridden by the module."
  }
}

variable "instance_name" {
  description = "Name of the GKE cluster instance"
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
  type = object({
    network_details = object({
      attributes = map(any)
    })
    cloud_account = object({
      attributes = object({
        project_id  = string
        region      = string
        credentials = string
      })
    })
  })
}

variable "instance" {
  description = "Instance configuration"
  type        = any

  # whitelisted_cidrs: a non-empty list of IPv4 CIDRs (an empty list would leave the endpoint open to everyone)
  validation {
    condition = (
      try(var.instance.spec.whitelisted_cidrs == null, true) ||
      try(length(var.instance.spec.whitelisted_cidrs) > 0 && alltrue([
        for cidr in var.instance.spec.whitelisted_cidrs :
        can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr)) && can(cidrhost(cidr, 0))
      ]), false)
    )
    error_message = "whitelisted_cidrs must be a non-empty list of IPv4 CIDRs, e.g. 203.0.113.10/32. Omit it to allow 0.0.0.0/0."
  }
}
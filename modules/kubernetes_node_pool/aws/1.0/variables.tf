# Required Facets variables
variable "instance" {
  description = "Instance configuration from Facets"
  type        = any
}

variable "instance_name" {
  description = "Name of the instance from Facets. Must follow Kubernetes naming conventions (RFC 1123 DNS subdomain format)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.instance_name)) && length(var.instance_name) >= 3 && length(var.instance_name) <= 63
    error_message = "Instance name must be 3-63 characters, start and end with alphanumeric characters, and contain only lowercase letters, numbers, and hyphens (RFC 1123 DNS subdomain format)."
  }
}

variable "environment" {
  description = "Environment object from Facets containing name and other attributes"
  type        = any
}

variable "inputs" {
  description = "Input dependencies from Facets"
  type        = any
}

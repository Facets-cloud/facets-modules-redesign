variable "instance" {
  type = object({
    spec = object({
      helm = object({
        chart               = string
        repository          = optional(string)
        version             = optional(string)
        namespace           = optional(string)
        wait                = optional(bool)
        timeout             = optional(number)
        recreate_pods       = optional(bool)
        repository_username = optional(string)
        repository_password = optional(string)
      })
      values = optional(any)
    })
  })

  validation {
    condition     = can(regex("^[a-zA-Z0-9]+(-[a-zA-Z0-9]+)*[a-zA-Z0-9]$", var.instance.spec.helm.chart))
    error_message = "Invalid chart name format. Only alphabets, numbers and hyphens are allowed."
  }

  validation {
    condition = (
      lookup(var.instance.spec.helm, "repository", null) == null ||
      can(regex("[a-zA-Z0-9:/._-]+", var.instance.spec.helm.repository))
    )
    error_message = "Invalid repository format. The URL or relative path should contain only valid characters [a-zA-Z0-9:/._-]."
  }

  validation {
    condition = (
      lookup(var.instance.spec.helm, "namespace", null) == null ||
      can(regex("^[a-zA-Z0-9]+(-[a-zA-Z0-9]+)*$", var.instance.spec.helm.namespace))
    )
    error_message = "Invalid namespace format. The namespace must be DNS-compliant, containing only letters, numbers, and hyphens, and must not start or end with a hyphen."
  }
}

variable "instance_name" {
  type        = string
  description = "Unique name for the Helm release instance"
  default     = "test_instance"
}

variable "environment" {
  type = object({
    namespace   = optional(string)
    unique_name = optional(string)
    cloud_tags  = optional(map(string))
  })
  description = "Environment-specific configuration"
  default = {
    namespace = "default"
  }
}

variable "inputs" {
  type        = any
  description = "Inputs from other modules"
  default     = {}
}

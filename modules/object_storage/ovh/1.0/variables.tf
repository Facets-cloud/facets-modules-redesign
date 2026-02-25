variable "instance_name" {
  type        = string
  description = "The architectural name for the resource as added in the Facets blueprint designer."
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
  description = "An object containing details about the environment."
}

variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      versioning_enabled   = optional(bool, false)
      encryption_enabled   = optional(bool, true)
      encryption_algorithm = optional(string, "AES256")
      replication_enabled  = optional(bool, false)
      replication_region   = optional(string, "")
      public_read          = optional(bool, false)
      lifecycle_enabled    = optional(bool, false)
      expiration_days      = optional(number, 0)
    })
  })
  description = "Module instance configuration"

  validation {
    condition     = var.instance.spec.encryption_algorithm == "AES256"
    error_message = "Encryption algorithm must be AES256."
  }

  validation {
    condition     = var.instance.spec.expiration_days >= 0
    error_message = "Expiration days must be a non-negative number."
  }

  validation {
    condition = !var.instance.spec.replication_enabled || (
      var.instance.spec.replication_enabled && var.instance.spec.replication_region != ""
    )
    error_message = "Replication region must be specified when replication is enabled."
  }
}

variable "inputs" {
  type = object({
    ovh_provider = object({
      attributes = object({
        endpoint           = optional(string)
        application_key    = optional(string)
        application_secret = optional(string)
        consumer_key       = optional(string)
        project_id         = string
      })
      interfaces = optional(object({}), {})
    })
  })
  description = "Input connections from other modules"
}

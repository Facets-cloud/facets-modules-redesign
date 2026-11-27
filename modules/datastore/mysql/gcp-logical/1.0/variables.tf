variable "instance" {
  description = "Logical Cloud SQL databases and shared users on an existing MySQL instance."
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      # source resolves (via x-ui-output-type: @facets/mysql) to the FULL outputs
      # of the selected MySQL resource: its attributes + interfaces (reader/writer).
      source = object({
        attributes = optional(any, {})
        interfaces = optional(map(object({
          host              = optional(string)
          port              = optional(number)
          username          = optional(string)
          password          = optional(string)
          database          = optional(string)
          connection_string = optional(string)
          secrets           = optional(list(string), [])
        })), {})
      })
      user_list                = optional(map(object({ database = optional(string, ""), host = optional(string, "%") })), {})
      managed_users            = optional(map(object({ host = optional(string, "%") })), {})
      canonical_passwords_json = optional(string, "{}")
      cloud_sql_instance       = optional(string)
      databases_json           = optional(string, "[]")
      database_name            = optional(string)
    })
  })

  validation {
    condition     = alltrue([for name in concat(keys(var.instance.spec.user_list), keys(var.instance.spec.managed_users)) : !contains(["reader", "writer"], name)])
    error_message = "The reader and writer interface names are reserved."
  }

  validation {
    condition     = try(length(trimspace(var.instance.spec.cloud_sql_instance)) > 0, false)
    error_message = "A Cloud SQL instance name is required."
  }
}

variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "GCP account used to manage logical Cloud SQL databases."
  type        = object({ cloud_account = object({ attributes = object({ project_id = string }) }) })
}

variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      name           = optional(string)
      namespace      = optional(string)
      resource_name  = optional(string)
      resource_type  = optional(string)
      driver         = optional(string)
      deletionPolicy = optional(string)
      schedule       = optional(string)
      retention_policy = optional(object({
        expires   = optional(string)
        max_count = optional(number)
      }))
      snapshot_tags                    = optional(map(string))
      labels                           = optional(map(string))
      annotations                      = optional(map(string))
      snapshot_template_labels         = optional(map(string))
      additional_claim_selector_labels = optional(map(string))
    })
  })
}

variable "inputs" {
  description = "Inputs from the dependent modules"
  type = object({
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider = optional(string)
        cluster_name   = optional(string)
        region         = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    snapshot_scheduler = object({
      attributes = object({
        release_name = optional(string)
      })

    })
  })
}

variable "instance_name" {
  type        = string
  description = "Unique architectural name from blueprint"
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    cloud       = string
    cloud_tags  = optional(map(string), {})
    namespace   = string
  })
}
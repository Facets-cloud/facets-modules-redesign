variable "instance" {
  description = "Resource configuration from the Facets blueprint."
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      # Map of GCP secret name -> resolved Facets secret value.
      secrets = optional(map(string), {})

      # Map of GCP secret name -> resolved Facets variable value.
      variables = optional(map(string), {})

      # Replication policy — applied to every secret created by this resource.
      replication = object({
        type         = string
        kms_key_name = optional(string)
        replicas = optional(map(object({
          location     = string
          kms_key_name = optional(string)
        })), {})
      })

      # GCP resource labels (merged with environment cloud_tags).
      labels = optional(map(string), {})

      # Annotations (no indexing/filtering constraints).
      annotations = optional(map(string), {})

      # Expiry — mutually exclusive; set one or neither.
      expire_time = optional(string)
      ttl         = optional(string)

      # Rotation policy — requires at least one topic.
      rotation = optional(object({
        next_rotation_time = optional(string)
        rotation_period    = optional(string)
      }))

      # Pub/Sub topics for secret lifecycle notifications (max 10).
      topics = optional(map(object({
        name = string
      })), {})
    })
  })
}

variable "instance_name" {
  type        = string
  description = "Logical resource name from the blueprint."
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
  description = "Facets environment metadata."
}

variable "inputs" {
  description = "Resolved inputs from dependent modules."
  type = object({
    cloud_account = object({
      attributes = object({
        project_id = string
      })
    })
  })
}

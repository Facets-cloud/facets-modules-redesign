variable "instance" {
  description = "Kafka topics configuration from facets.yaml spec"
  type = object({
    kind     = string
    flavor   = string
    version  = string
    metadata = map(string)
    spec = object({
      topics = map(object({
        partitions         = number
        replication_factor = number
        config             = optional(map(string), {})
      }))
    })
  })

  validation {
    condition = alltrue([
      for key, topic in var.instance.spec.topics :
      topic.partitions >= 1
    ])
    error_message = "Each topic must have at least 1 partition."
  }

  validation {
    condition = alltrue([
      for key, topic in var.instance.spec.topics :
      topic.replication_factor >= 1
    ])
    error_message = "Each topic must have at least 1 replication_factor."
  }
}

variable "instance_name" {
  description = "The name of the Kafka topic resource"
  type        = string
}

variable "environment" {
  description = "Environment details"
  type = object({
    name        = string
    unique_name = string
  })
}

variable "inputs" {
  description = "Module dependencies"
  type = object({
    kubernetes_cluster = object({
      attributes = optional(object({
        cloud_provider   = optional(string)
        cluster_id       = optional(string)
        cluster_name     = optional(string)
        cluster_location = optional(string)
        cluster_endpoint = optional(string)
      }), {})
      interfaces = optional(object({
        kubernetes = optional(object({
          cluster_ca_certificate = optional(string)
          host                   = optional(string)
        }), {})
      }), {})
    })
    kafka_cluster = object({
      attributes = object({
        namespace    = string
        cluster_name = string
      })
      interfaces = optional(object({
        cluster = optional(object({
          connection_string = optional(string)
          endpoint          = optional(string)
          endpoints         = optional(string)
          password          = optional(string)
          username          = optional(string)
        }), {})
      }), {})
    })
  })
}

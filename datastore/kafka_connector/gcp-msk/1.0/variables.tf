variable "instance" {
  description = "GCP Managed Kafka Connector configuration"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      connector_id = string
      configs      = map(string)
      task_restart_policy = optional(object({
        minimum_backoff = string
        maximum_backoff = string
      }))
    })
  })

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.instance.spec.connector_id))
    error_message = "Connector ID must contain only lowercase letters, numbers, and hyphens"
  }

  validation {
    condition = (
      var.instance.spec.task_restart_policy == null ||
      (can(regex("^[0-9]+(\\.[0-9]+)?s$", var.instance.spec.task_restart_policy.minimum_backoff)) &&
      can(regex("^[0-9]+(\\.[0-9]+)?s$", var.instance.spec.task_restart_policy.maximum_backoff)))
    )
    error_message = "Backoff values must be durations in seconds format (e.g., '60s', '1800s')"
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
  description = "Input dependencies from other modules"
  type = object({
    kafka_cluster = object({
      attributes = object({
        connect_cluster_id       = string
        connect_cluster_location = string
      })
    })
    gcp_cloud_account = object({
      attributes = object({
        project_id = string
        region     = string
      })
    })
    vpc_network = object({
      attributes = object({
        vpc_id            = string
        private_subnet_id = string
      })
    })
  })
  # Validation: Ensure connect cluster is enabled in the kafka module
  validation {
    condition     = var.inputs.kafka_cluster.attributes.connect_cluster_id != null
    error_message = "Kafka Connect cluster must be enabled in the Kafka cluster module. Set connect_cluster: true in the Kafka cluster configuration."
  }
}

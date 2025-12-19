variable "instance" {
  description = "GCP Managed Kafka Topic configuration"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      partition_count    = optional(number, 1)
      replication_factor = number
      configs            = optional(map(string), {})
    })
  })

  validation {
    condition     = var.instance.spec.partition_count >= 1 && var.instance.spec.partition_count <= 1000
    error_message = "Partition count must be between 1 and 1000"
  }

  validation {
    condition     = var.instance.spec.replication_factor >= 1 && var.instance.spec.replication_factor <= 5
    error_message = "Replication factor must be between 1 and 5. A replication factor of 3 is recommended for high availability."
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
        cluster_id = string
        location   = string
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
}

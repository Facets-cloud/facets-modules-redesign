variable "environment" {
  description = "Environment details"
  type = object({
    name                 = string
    unique_name          = string
    namespace            = string
    environment_id       = string
    cloud_provider       = string
    cloud_provider_id    = string
    cloud_region         = string
    cloud_availability_zones = list(string)
    cloud_tags           = map(string)
  })
}

variable "instance" {
  description = "Instance configuration from facets.yaml spec"
  type = object({
    kind     = string
    flavor   = string
    version  = string
    metadata = map(string)
    spec = object({
      name                  = string
      volume_type           = string
      is_default            = bool
      iops                  = optional(number)
      throughput            = optional(number)
      encrypted             = optional(bool, true)
      reclaim_policy        = optional(string, "Delete")
      volume_binding_mode   = optional(string, "WaitForFirstConsumer")
      allow_volume_expansion = optional(bool, true)
    })
  })
}

variable "instance_name" {
  description = "Name of the resource instance"
  type        = string
}

variable "inputs" {
  description = "Inputs from other resources"
  type = object({
    kubernetes_cluster = optional(object({
      attributes = object({
        cluster_endpoint       = string
        cluster_ca_certificate = string
        cluster_name           = string
      })
    }))
  })
}

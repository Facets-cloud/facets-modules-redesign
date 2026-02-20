variable "instance" {
  description = "Instance configuration from facets.yaml spec"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      name                   = string
      volume_type            = string
      is_default             = optional(bool, true)
      iops                   = optional(number)
      throughput             = optional(number, 125)
      encrypted              = optional(bool, true)
      reclaim_policy         = optional(string, "Delete")
      volume_binding_mode    = optional(string, "WaitForFirstConsumer")
      allow_volume_expansion = optional(bool, true)
    })
  })
}

variable "instance_name" {
  description = "Unique architectural name from blueprint"
  type        = string
}

variable "environment" {
  description = "Environment context including name and cloud tags"
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "Inputs from dependent modules"
  type = object({
    kubernetes_cluster = object({
      attributes = object({
        cluster_endpoint       = string
        cluster_ca_certificate = string
        cluster_name           = string
      })
    })
  })
}

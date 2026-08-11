variable "instance" {
  description = "Instance configuration from facets.yaml spec"
  type = object({
    spec = object({
      name                   = string
      volume_type            = string
      is_default             = optional(bool, true)
      iops = optional(number)
      # NO defaults on throughput/encrypted: a typed default is materialised by terraform even when the
      # spec omits the key, which would force those parameters into the rendered (IMMUTABLE) parameter
      # map and break adoption of live StorageClasses that do not carry them.
      throughput = optional(number)
      encrypted  = optional(bool)
      # Adoption overrides
      storage_provisioner = optional(string)
      fs_type             = optional(string)
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

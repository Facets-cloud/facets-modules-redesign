
variable "instance" {
  description = "Instance configuration for the GKE node fleet"
  type = object({
    metadata = optional(object({
      name   = optional(string)
      labels = optional(map(string), {})
    }), {})
    spec = object({
      node_pools = map(object({
        instance_type        = string
        min_node_count       = number
        max_node_count       = number
        disk_size            = number
        disk_type            = optional(string, "pd-standard")
        is_public            = optional(bool, false)
        spot                 = optional(bool, false)
        autoscaling_per_zone = optional(bool, false)
        single_az            = optional(bool, false)
        azs                  = optional(list(string))
        iam = optional(object({
          roles = optional(map(object({
            role = string
          })), {})
        }), {})
      }))
      labels = optional(map(string), {})
      taints = optional(list(object({
        key    = string
        value  = string
        effect = string
      })), [])
    })
    advanced = optional(object({
      gke = optional(map(any), {})
    }), {})
  })
}

variable "inputs" {
  description = "Input dependencies for the GKE node fleet"
  type = object({
    network_details = object({
      attributes = object({
        zones = optional(list(string), [])
      })
    })
    kubernetes_details = object({
      cluster_name    = string
      cluster_version = optional(string)
      auto_upgrade    = optional(bool, true)
      attributes      = optional(map(any), {})
    })
    cloud_account = object({
      attributes = object({
        project_id = string
        region     = string
      })
    })
  })
}

variable "instance_name" {
  description = "Name of the node fleet instance"
  type        = string
  default     = "node-fleet"
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    namespace   = string
  })
}
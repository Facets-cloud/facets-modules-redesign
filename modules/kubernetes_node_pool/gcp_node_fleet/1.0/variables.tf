
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
      attributes = optional(object({
        zones = optional(list(string), [])
      }), {})
      interfaces = optional(object({}), {})
    })
    kubernetes_details = object({
      attributes = optional(object({
        auto_upgrade           = optional(string)
        cloud_provider         = optional(string)
        cluster_ca_certificate = optional(string)
        cluster_endpoint       = optional(string)
        cluster_id             = optional(string)
        cluster_ipv4_cidr      = optional(string)
        cluster_location       = optional(string)
        cluster_name           = optional(string)
        cluster_version        = optional(string)
        kubernetes_provider_exec = optional(object({
          api_version = optional(string)
          args        = optional(list(string))
          command     = optional(string)
        }))
        maintenance_policy_enabled             = optional(string)
        master_authorized_networks_config      = optional(string)
        network                                = optional(string)
        pods_range_name                        = optional(string)
        project_id                             = optional(string)
        region                                 = optional(string)
        release_channel                        = optional(string)
        secrets                                = optional(string)
        services_range_name                    = optional(string)
        subnetwork                             = optional(string)
        workload_identity_config_workload_pool = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    cloud_account = object({
      attributes = optional(object({
        credentials = optional(string)
        project_id  = optional(string)
        region      = optional(string)
      }), {})
      interfaces = optional(object({}), {})
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
    cloud_tags  = optional(map(string), {})
  })
}
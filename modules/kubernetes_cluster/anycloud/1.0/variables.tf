variable "instance" {
  type = object({
    spec = object({
      aws = object({
        addons = optional(object({
          coredns        = optional(bool)
          ebs_csi        = optional(bool)
          kube_proxy     = optional(bool)
          metrics_server = optional(bool)
          vpc_cni        = optional(bool)
        }))
        authentication_mode             = optional(string)
        bootstrap_cluster_creator_admin = optional(bool)
        enable_irsa                     = optional(bool)
        enabled_log_types               = optional(list(string))
        endpoint_private_access         = bool
        endpoint_public_access          = bool
        public_access_cidrs             = optional(list(string))
        tags                            = optional(map(any))
      })
      cluster_version = string
      gcp = object({
        cost_management_enabled    = optional(bool)
        enable_private_nodes       = bool
        maintenance_recurrence     = optional(string)
        maintenance_start_time     = optional(string)
        managed_prometheus_enabled = optional(bool)
        network_policy_enabled     = optional(bool)
        logging_enabled            = optional(bool)
        master_authorized_networks = optional(map(any))
        nap_enabled                = optional(bool)
        nap_max_cpu                = optional(number)
        nap_max_memory_gb          = optional(number)
        nap_min_cpu                = optional(number)
        nap_min_memory_gb          = optional(number)
        release_channel            = string
        zone                       = optional(string)
      })
      default_node_pool = optional(object({
        enabled = optional(bool)
        aws = optional(object({
          instance_type      = optional(string)
          instance_types     = optional(list(string))
          capacity_type      = optional(string)
          ami_type           = optional(string)
          disk_size_gb       = optional(number)
          min_size           = optional(number)
          max_size           = optional(number)
          desired_size       = optional(number)
          max_unavailable    = optional(number)
          availability_zones = optional(list(string))
        }))
        gcp = optional(object({
          machine_type                = optional(string)
          disk_type                   = optional(string)
          disk_size_gb                = optional(number)
          spot                        = optional(bool)
          autoscaling_enabled         = optional(bool)
          min_node_count              = optional(number)
          max_node_count              = optional(number)
          image_type                  = optional(string)
          auto_repair                 = optional(bool)
          auto_upgrade                = optional(bool)
          upgrade_max_surge           = optional(number)
          upgrade_max_unavailable     = optional(number)
          max_pods_per_node           = optional(number)
          enable_secure_boot          = optional(bool)
          enable_integrity_monitoring = optional(bool)
          service_account_email       = optional(string)
          location                    = optional(string)
          node_locations              = optional(list(string))
        }))
      }))
      name = optional(string)
    })
  })
}

variable "instance_name" {
  type        = string
  description = "Resource name in the blueprint (architectural name, e.g. main-db, api)"
}

variable "environment" {
  type = object({
    name        = string # Environment name (e.g., dev, staging, prod)
    unique_name = string # Project + environment (globally unique, e.g., myapp-prod)
  })
  description = "Environment context. Use unique_name + instance_name for globally unique resource names."
}

variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = optional(object({
        aws = optional(object({
          external_id = optional(string)
          region      = optional(string)
          role_arn    = optional(string)
        }))
        cloud_provider = optional(string)
        gcp = optional(object({
          access_token = optional(string)
          credentials  = optional(string)
          project_id   = optional(string)
          region       = optional(string)
        }))
      }))
      interfaces = optional(object({}))
    })
    network = object({
      attributes = optional(object({
        cidr               = optional(string)
        cloud_provider     = optional(string)
        network_id         = optional(string)
        private_subnet_ids = optional(list(string))
        public_subnet_ids  = optional(list(string))
        region             = optional(string)
      }))
      interfaces = optional(object({
        gcp = optional(object({
          gke_pods_range_name     = optional(string)
          gke_services_range_name = optional(string)
        }))
        aws = optional(object({}))
      }))
    })
  })
}

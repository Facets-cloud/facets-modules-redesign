variable "instance" {
  type = any
  default = {
    spec = {
      instance_type  = "e2-medium"
      min_node_count = 1
      max_node_count = 1
      disk_size      = 100
      taints         = []
      labels         = {}
    }
  }
}

variable "instance_name" {
  type    = string
  default = "private-nodepool"
}

variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = optional(object({
        credentials = optional(string)
        project_id  = optional(string)
        region      = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    network_details = object({
      attributes = optional(object({
        database_subnet_cidrs               = optional(list(string))
        database_subnet_ids                 = optional(list(string))
        firewall_rule_ids                   = optional(list(string))
        gke_pods_range_name                 = optional(string)
        nat_gateway_ids                     = optional(list(string))
        private_services_connection_id      = optional(string)
        private_services_connection_status  = optional(bool)
        private_services_peering_connection = optional(string)
        private_services_range_address      = optional(string)
        private_services_range_id           = optional(string)
        private_services_range_name         = optional(string)
        private_subnet_cidrs                = optional(list(string))
        private_subnet_ids                  = optional(list(string))
        project_id                          = optional(string)
        public_subnet_cidrs                 = optional(list(string))
        public_subnet_ids                   = optional(list(string))
        region                              = optional(string)
        router_ids                          = optional(list(string))
        vpc_id                              = optional(string)
        vpc_name                            = optional(string)
        vpc_self_link                       = optional(string)
        zones                               = optional(list(string))
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
        master_authorized_networks_config      = optional(list(string))
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
  })
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    namespace   = string
    cloud_tags  = map(string)
  })
}

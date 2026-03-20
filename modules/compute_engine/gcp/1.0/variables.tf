variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
}

variable "environment" {
  description = "Environment configuration."
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "Input references from other modules."
  type = object({
    cloud_account = object({
      attributes = optional(object({
        credentials = optional(string)
        project_id  = optional(string)
        project     = optional(string)
        region      = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    network_details = object({
      attributes = optional(object({
        region                              = optional(string)
        vpc_self_link                       = optional(string)
        vpc_name                            = optional(string)
        vpc_id                              = optional(string)
        private_subnet_ids                  = optional(list(string), [])
        private_subnet_cidrs                = optional(list(string), [])
        public_subnet_ids                   = optional(list(string), [])
        public_subnet_cidrs                 = optional(list(string), [])
        database_subnet_ids                 = optional(list(string), [])
        database_subnet_cidrs               = optional(list(string), [])
        project_id                          = optional(string)
        zones                               = optional(list(string), [])
        nat_gateway_ids                     = optional(list(string), [])
        router_ids                          = optional(list(string), [])
        firewall_rule_ids                   = optional(list(string), [])
        private_services_connection_id      = optional(string)
        private_services_connection_status  = optional(bool)
        private_services_peering_connection = optional(string)
        private_services_range_address      = optional(string)
        private_services_range_id           = optional(string)
        private_services_range_name         = optional(string)
        vpc_connector_enabled               = optional(bool)
        vpc_connector_id                    = optional(string)
        vpc_connector_name                  = optional(string)
        vpc_connector_self_link             = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}

variable "instance" {
  description = "Compute Engine module configuration."
  type = object({
    kind    = optional(string)
    flavor  = optional(string)
    version = optional(string)
    spec = object({
      machine_type = optional(string, "e2-standard-2")
      zone         = string
      boot_disk = optional(object({
        image   = optional(string, "debian-cloud/debian-11")
        size_gb = optional(number, 50)
        type    = optional(string, "pd-ssd")
      }), {})
      network = optional(object({
        vpc_name         = optional(string, "")
        subnetwork       = optional(string, "")
        assign_public_ip = optional(bool, true)
      }), {})
      startup_script = optional(string, "")
      tags           = optional(list(string), [])
      open_ports = optional(map(object({
        port          = string
        protocol      = optional(string, "tcp")
        source_ranges = optional(list(string), ["0.0.0.0/0"])
      })), {})
      service_account = optional(object({
        email  = optional(string, "")
        scopes = optional(list(string), ["https://www.googleapis.com/auth/cloud-platform"])
      }), {})
    })
  })
}

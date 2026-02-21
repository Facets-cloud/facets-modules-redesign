variable "instance" {
  description = "Creates and manages an OVH Managed Kubernetes Service (MKS) cluster, exposing Kubernetes and Helm providers"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      plan = string
    })
  })

  validation {
    condition     = contains(["free", "standard"], var.instance.spec.plan)
    error_message = "plan must be either 'free' or 'standard'."
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
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    ovh_provider = object({
      attributes = object({
        endpoint           = string
        application_key    = string
        application_secret = string
        consumer_key       = string
        project_id         = string
      })
    })
    network = object({
      attributes = object({
        network_id           = string
        network_name         = string
        network_cidr         = string
        openstack_network_id = string
        region               = string
        project_id           = string
        k8s_subnet_id        = string
        k8s_subnet_cidr      = string
        k8s_gateway_ip       = string
        gateway_id           = string
        db_subnet_id         = string
        db_subnet_cidr       = string
        lb_subnet_id         = string
        lb_subnet_cidr       = string
      })
    })
  })
}

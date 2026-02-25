variable "instance" {
  description = "Creates and manages OVH Managed Kubernetes node pools with support for multi-AZ deployments"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      flavor_name    = string
      desired_nodes  = number
      max_nodes      = number
      autoscale      = bool
      monthly_billed = bool
      availability_zones = optional(map(object({
        name = string
      })), {})
      labels = optional(map(object({
        key   = string
        value = string
      })), {})
      taints = optional(map(object({
        value  = optional(string, "")
        effect = string
      })), {})
    })
  })

  validation {
    condition     = var.instance.spec.max_nodes >= var.instance.spec.desired_nodes
    error_message = "max_nodes must be greater than or equal to desired_nodes."
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
    kubernetes_cluster = object({
      attributes = object({
        cluster_id             = string
        cluster_name           = string
        cluster_endpoint       = string
        cluster_ca_certificate = string
        client_certificate     = string
        client_key             = string
        kubeconfig             = string
        region                 = string
        version                = string
        status                 = string
      })
    })
  })
}

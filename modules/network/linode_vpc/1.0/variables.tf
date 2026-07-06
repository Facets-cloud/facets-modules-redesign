variable "instance" {
  description = "Creates a Linode VPC with a subnet for Kubernetes and managed services"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      region      = optional(string)
      subnet_cidr = string
    })
  })

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.instance.spec.subnet_cidr))
    error_message = "subnet_cidr must be a valid CIDR block (e.g., 10.0.0.0/24)."
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
    linode_cloud_account = object({
      attributes = object({
        token  = string
        region = string
      })
    })
  })
}

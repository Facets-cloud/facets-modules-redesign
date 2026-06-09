variable "instance" {
  description = "S3-compatible object storage subscription on Vultr with access credentials"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      cluster_hostname = optional(string, "ewr1.vultrobjects.com")
      tier_id          = optional(number, 2)
    })
  })
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
    vultr_cloud_account = object({
      attributes = object({
        api_key = string
        region  = string
      })
    })
  })
}

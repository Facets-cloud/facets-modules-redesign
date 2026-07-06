variable "instance" {
  description = "S3-compatible object storage bucket on Linode (Akamai) with access credentials"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      region             = optional(string, "us-east")
      acl                = optional(string, "private")
      versioning_enabled = optional(bool, false)
      cors_enabled       = optional(bool, false)
    })
  })

  validation {
    condition     = contains(["private", "public-read", "authenticated-read", "public-read-write"], var.instance.spec.acl)
    error_message = "acl must be one of: private, public-read, authenticated-read, public-read-write."
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

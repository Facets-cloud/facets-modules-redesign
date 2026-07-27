variable "instance" {
  description = "Create PostgreSQL databases on an existing Aurora or RDS Postgres cluster as a standalone resource, so the cluster's own blueprint never has to change."
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      databases = list(object({
        name       = string
        owner_role = string
      }))
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
    postgres_cluster = object({
      interfaces = object({
        writer = object({
          host              = string
          port              = string
          username          = string
          password          = string
          connection_string = string
          database          = string
          secrets           = list(string)
        })
      })
    })
    kubernetes_cluster = object({
      attributes = object({
        cloud_provider   = string
        cluster_id       = string
        cluster_name     = string
        cluster_location = string
        cluster_endpoint = string
      })
    })
  })
}

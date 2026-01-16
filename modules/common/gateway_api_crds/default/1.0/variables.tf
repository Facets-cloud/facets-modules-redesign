variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      gateway_api_version = optional(string, "v1.2.0")
    })
  })
}

variable "instance_name" {
  type        = string
  description = "Unique architectural name from blueprint"
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
  description = "Environment configuration"
}

variable "inputs" {
  type = object({
    kubernetes_cluster = object({
      attributes = object({
        cluster_endpoint       = string
        cluster_ca_certificate = string
        cluster_name           = optional(string)
      })
    })
  })
  description = "Input dependencies from other modules"
}

variable "instance" {
  type    = any
  default = {}
}

variable "instance_name" {
  type    = string
  default = "test_instance"
}


variable "environment" {
  type = any
  default = {
    namespace = "default"
  }
}

variable "inputs" {
  type = object({
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider   = optional(string)
        cluster_id       = optional(string)
        cluster_name     = optional(string)
        cluster_location = optional(string)
        cluster_endpoint = optional(string)
      }))
      interfaces = optional(object({
        kubernetes = optional(object({
          cluster_ca_certificate = optional(string)
          host                   = optional(string)
        }))
      }))
    })
  })
}

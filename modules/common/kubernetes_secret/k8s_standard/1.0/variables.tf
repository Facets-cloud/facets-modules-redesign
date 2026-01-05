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
      attributes = object({
        cluster_endpoint = string
        cluster_name     = optional(string)
        cluster_id       = optional(string)
      })
      interfaces = optional(object({
        kubernetes = optional(object({
          host                   = string
          cluster_ca_certificate = string
        }))
      }))
    })
  })
}

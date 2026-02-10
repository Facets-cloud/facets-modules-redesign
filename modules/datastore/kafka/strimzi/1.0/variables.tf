variable "instance" {
  description = "Kafka cluster deployment configuration"
  type        = any
}

variable "instance_name" {
  description = "The architectural name for the Kafka cluster resource"
  type        = string
}

variable "environment" {
  description = "Environment details"
  type = object({
    name        = string
    unique_name = string
  })
}

variable "inputs" {
  description = "Module dependencies"
  type = object({
    kubernetes_cluster = object({
      attributes = any
      interfaces = any
    })
    strimzi_operator = object({
      attributes = any
      interfaces = any
    })
    node_pool = optional(object({
      attributes = any
      interfaces = any
    }))
  })
}

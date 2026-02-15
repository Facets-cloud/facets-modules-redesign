variable "instance" {
  description = "Facets instance object containing spec and metadata"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec    = any
  })
}

variable "instance_name" {
  description = "Unique architectural name from blueprint"
  type        = string
}

variable "environment" {
  description = "An object containing details about the environment"
  type        = any
}

variable "inputs" {
  description = "Input variables from dependencies"
  type = object({
    kubernetes_details = any
    kubernetes_node_pool_details = object({
      attributes = optional(object({
        node_class_name = optional(string)
        node_pool_name  = optional(string)
        taints = optional(list(object({
          key    = string
          value  = string
          effect = string
        })), [])
        node_selector = optional(map(string), {})
      }))
      interfaces = optional(object({}))
    })
    prometheus_details = optional(any)
  })
}

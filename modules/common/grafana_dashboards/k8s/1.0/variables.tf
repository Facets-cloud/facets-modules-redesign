variable "instance" {
  description = "Instance configuration for Grafana dashboards"
  type = object({
    spec = any
  })
}

variable "instance_name" {
  description = "Name of the Grafana dashboards instance"
  type        = string
}

variable "environment" {
  description = "Environment configuration"
  type = object({
    name       = string
    namespace  = string
    cloud_tags = map(string)
  })
}

variable "inputs" {
  description = "Input resources for the module"
  type = object({
    kubernetes_details = object({
      resource_name = string
      resource_type = string
    })
    prometheus = object({
      attributes = object({
        namespace = string
      })
    })
  })
}

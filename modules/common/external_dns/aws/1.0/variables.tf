variable "instance" {
  type = object({
    spec = object({
      hosted_zone_id = optional(string, "")
    })
  })
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
    kubernetes_details = any
    cloud_account      = any
  })
}

variable "cc_metadata" {
  type = any
  default = {}
}

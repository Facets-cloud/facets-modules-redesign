variable "instance" {
  type = object({
    spec = object({})
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
  })
}

variable "instance" {
  type = any
  default = {
    spec = {
      instance_type  = "e2-medium"
      min_node_count = 1
      max_node_count = 1
      disk_size      = 100
      taints         = []
      labels         = {}
    }
  }
}

variable "instance_name" {
  type    = string
  default = "private-nodepool"
}

variable "inputs" {
  type    = any
  default = {}
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    namespace   = string
  })
}

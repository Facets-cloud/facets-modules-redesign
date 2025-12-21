variable "instance" {
  type    = any
  default = {}
}

variable "instance_name" {
  type    = string
  default = ""
}

variable "inputs" {
  type    = any
  default = []
}

variable "environment" {
  type    = any
  default = {}
}

# cc_metadata is injected by Facets at runtime
# Not allowed to be declared in variables.tf for new modules

variable "instance" {
  type        = any
  description = "The resource instance configuration"
}

variable "instance_name" {
  type        = string
  description = "The name of the resource instance"
}

variable "inputs" {
  type        = any
  description = "Input resources and their outputs"
  default     = {}
}

variable "environment" {
  type        = string
  description = "The environment name"
}

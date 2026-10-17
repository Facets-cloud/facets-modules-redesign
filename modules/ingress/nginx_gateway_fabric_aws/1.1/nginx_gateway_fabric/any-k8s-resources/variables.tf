variable "name" {
  type = string
}

variable "advanced_config" {
  type = any
}

variable "namespace" {
  type = string
}

variable "resources_data" {
  type = any
}

variable "release_name" {
  type    = string
  default = null
}

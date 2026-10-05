variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "access_modes" {
  type    = list(string)
  default = ["ReadWriteOnce"]
}

variable "volume_size" {
  type = string
}

variable "provisioned_for" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "kind" {
  type = string
}

variable "additional_labels" {
  type = map(string)
  default = {}
}

variable "annotations" {
  type = map(string)
  default = {}
}

variable "cloud_tags" {
  type = any
  default = {}
}

# variable "storage_class_name" {
#   type = string
#   default = null
# }

variable "storage_class_name" {
  type = string
  default = null
  
}
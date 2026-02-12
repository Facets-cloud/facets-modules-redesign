variable "instance" {
  description = "Consolidated service module supporting multiple workload types for OVH Kubernetes"
  type        = any
}

variable "inputs" {
  description = "Input dependencies from other modules including Kubernetes cluster and container registry credentials"
  type        = any
}

variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
  default     = "test_instance"
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    namespace   = optional(string, "default")
    cloud_tags  = optional(map(string), {})
  })
  default = {
    name        = "default"
    unique_name = "default"
    namespace   = "default"
  }
}

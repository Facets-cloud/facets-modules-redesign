variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
  default     = "test_instance"
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = optional(string)
    unique_name = optional(string)
    cloud_tags  = optional(map(string), {})
    namespace   = optional(string, "default")
  })
  default = {
    namespace = "default"
  }
}

#########################################################################
# Instance Configuration Schema                                         #
#                                                                       #
# Matches the spec defined in facets.yaml                              #
#########################################################################

variable "instance" {
  description = "The external DNS resource instance configuration"
  type = object({
    kind     = optional(string)
    flavor   = optional(string)
    version  = optional(string)
    disabled = optional(bool, false)
    spec = object({
      hosted_zone_id = optional(string, "")
    })
  })
}



variable "inputs" {
  description = "Input dependencies from other modules"
  type = object({
    kubernetes_details = object({
      attributes = object({
        cluster_name     = string
        cluster_endpoint = optional(string)
        cloud_provider   = optional(string)
      })
      interfaces = optional(any)
    })
    cloud_account = object({
      attributes = object({
        aws_region   = string
        aws_iam_role = optional(string)
        external_id  = optional(string)
      })
    })
  })
}

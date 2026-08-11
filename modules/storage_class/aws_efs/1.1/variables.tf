variable "instance" {
  description = "Instance configuration from facets.yaml spec"
  type = object({
    spec = object({
      name                  = optional(string)
      reclaim_policy        = optional(string, "Delete")
      volume_binding_mode   = optional(string, "Immediate")
      directory_permissions = optional(string, "700")
    })
  })
}

variable "instance_name" {
  description = "Unique architectural name from blueprint"
  type        = string
}

variable "environment" {
  description = "Environment context including name and cloud tags"
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "Inputs from dependent modules"
  type = object({
    kubernetes_cluster = object({
      attributes = object({
        cluster_endpoint       = string
        cluster_ca_certificate = string
        cluster_name           = string
      })
    })
    csi_driver = object({
      attributes = optional(object({
        iam_role_arn    = optional(string)
        helm_release_id = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    aws_efs = object({
      attributes = optional(object({
        file_system_id    = optional(string)
        security_group_id = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}

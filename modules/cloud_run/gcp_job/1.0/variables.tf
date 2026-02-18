# =============================================================================
# FACETS STANDARD VARIABLES
# =============================================================================

variable "instance" {
  description = "Facets instance configuration"
  type        = any
}

variable "instance_name" {
  description = "Name of the resource instance"
  type        = string
}

variable "environment" {
  description = "Environment configuration"
  type        = any
}

variable "cluster" {
  description = "Cluster configuration"
  type        = any
  default     = {}
}

# =============================================================================
# INPUT RESOURCES
# =============================================================================

variable "inputs" {
  description = "Facets input resources"
  type = object({
    gcp_provider = object({
      attributes = object({
        project_id = string
        region     = string
      })
    })
    network = optional(object({
      attributes = object({
        vpc_name           = optional(string)
        vpc_self_link      = optional(string)
        subnet_name        = optional(string)
        vpc_connector_name = optional(string)
      })
    }), null)
  })
}

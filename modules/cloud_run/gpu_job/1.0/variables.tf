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

# =============================================================================
# INPUT RESOURCES
# =============================================================================

variable "inputs" {
  description = "Facets input resources. Required: cloud_account. Optional: network_details"
  type        = any
}

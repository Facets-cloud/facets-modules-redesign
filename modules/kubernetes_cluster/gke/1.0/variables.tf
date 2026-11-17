variable "instance_name" {
  description = "Name of the GKE cluster instance"
  type        = string
}

variable "environment" {
  description = "Environment configuration"
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "Input references from other modules"
  type = object({
    network_details = object({
      # `any`, not map(any): network outputs mix strings and lists (zones, database_subnet_ids),
      # which map(any) cannot unify. CRD releases enforce this type; backend releases did not.
      attributes = any
    })
    cloud_account = object({
      attributes = object({
        project_id  = string
        region      = string
        credentials = string
      })
    })
  })
}

variable "instance" {
  description = "Instance configuration"
  type        = any
}
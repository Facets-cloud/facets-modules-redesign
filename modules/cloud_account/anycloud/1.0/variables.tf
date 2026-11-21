variable "instance" {
  type = object({
    spec = object({
      aws_cloud_account = optional(string)
      aws_region        = optional(string)
      cloud_provider    = optional(string)
      gcp_cloud_account = optional(string)
      gcp_region        = optional(string)
    })
  })
}

variable "instance_name" {
  type        = string
  description = "Resource name in the blueprint (architectural name, e.g. main-db, api)"
}

variable "environment" {
  type = object({
    name        = string # Environment name (e.g., dev, staging, prod)
    unique_name = string # Project + environment (globally unique, e.g., myapp-prod)
  })
  description = "Environment context. Use unique_name + instance_name for globally unique resource names."
}

variable "inputs" {
  type = object({})
}

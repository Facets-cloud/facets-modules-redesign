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
      attributes = map(any)
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

  # Validate initial node count
  validation {
    condition = (
      lookup(var.instance.spec, "initial_node_count", 3) >= 1 &&
      lookup(var.instance.spec, "initial_node_count", 3) <= 100
    )
    error_message = "Initial node count must be between 1 and 100."
  }


  # Validate autoscaling min/max
  validation {
    condition = (
      lookup(var.instance.spec, "enable_autoscaling", true) == false ||
      (
        lookup(var.instance.spec, "min_nodes", 1) >= 1 &&
        lookup(var.instance.spec, "max_nodes", 10) > lookup(var.instance.spec, "min_nodes", 1) &&
        lookup(var.instance.spec, "max_nodes", 10) <= 100
      )
    )
    error_message = "When autoscaling is enabled, min_nodes must be >= 1, max_nodes must be > min_nodes and <= 100."
  }
}
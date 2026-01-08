variable "instance" {
  type = object({
    spec = object({
      topic_name                 = string
      message_retention_duration = optional(string)
      create_subscription        = optional(bool)
      subscription_ack_deadline  = optional(number)
    })
  })

  validation {
    condition     = can(var.instance.spec.topic_name) && length(var.instance.spec.topic_name) > 0
    error_message = "Topic name must be provided and cannot be empty"
  }

  validation {
    condition     = can(var.instance.spec.message_retention_duration) ? can(regex("^\\d+s$", var.instance.spec.message_retention_duration)) : true
    error_message = "Message retention duration must be in seconds format (e.g., '604800s')"
  }

  validation {
    condition     = can(var.instance.spec.subscription_ack_deadline) ? (var.instance.spec.subscription_ack_deadline >= 10 && var.instance.spec.subscription_ack_deadline <= 600) : true
    error_message = "Subscription ack deadline must be between 10 and 600 seconds"
  }
}

variable "instance_name" {
  type    = string
  default = "pubsub"
}

variable "environment" {
  type = any
  default = {
    namespace = "default"
  }
}

variable "inputs" {
  type = object({
    cloud_account = optional(object({
      attributes = optional(object({
        credentials = optional(string)
        project     = optional(string)
        project_id  = optional(string)
        region      = optional(string)
      }))
      interfaces = optional(object({}))
    }))
  })
  default = {}
}

variable "instance" {
  description = "The resource instance from the blueprint, including its spec."
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      name      = optional(string)
      namespace = optional(string, "default")
      # MUST be declared here: spec is a closed object type, so an undeclared field is silently
      # DROPPED before the module sees it — a blueprint setting create_namespace: false would be
      # ignored without this line, and --dry-run does not catch that.
      create_namespace = optional(bool, true)
      data = optional(map(object({
        content = string
      })), {})
      immutable   = optional(bool, false)
      labels      = optional(map(string), {})
      annotations = optional(map(string), {})
    })
  })
}

variable "instance_name" {
  description = "Architectural name of the resource in the blueprint."
  type        = string
}

variable "environment" {
  description = "Environment the resource is deployed into."
  type = object({
    name        = string
    unique_name = string
    namespace   = optional(string)
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "Wired module inputs."
  type = object({
    kubernetes_cluster = object({
      attributes = optional(object({
        cloud_provider = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}

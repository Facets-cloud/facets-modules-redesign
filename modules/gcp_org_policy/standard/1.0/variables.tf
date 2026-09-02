variable "instance" {
  description = "Instance configuration"
  type = object({
    kind     = optional(string)
    flavor   = optional(string)
    version  = optional(string)
    disabled = optional(bool, false)
    spec = object({
      constraints = optional(list(object({
        constraint = string
        rule_type  = string
        # MUST carry an explicit default. optional(bool) with no default
        # materialises as null, lookup() then returns that null, and
        # `null ? "TRUE" : "FALSE"` is a hard Terraform error
        # ("condition value is null"). allowed_values/denied_values below are
        # deliberately left defaultless — null is the correct value there.
        enforce = optional(bool, false)
        # For LIST constraints, `values{}` / `deny_all` / `allow_all` are mutually
        # exclusive alternatives in the same rules block. deny_all is the ONLY way
        # to deny every value — there is no magic "all" string, and passing
        # denied_values = ["all"] creates a policy that matches nothing and
        # silently enforces nothing. Same explicit-default rule as `enforce`.
        deny_all            = optional(bool, false)
        allow_all           = optional(bool, false)
        allowed_values      = optional(list(string))
        denied_values       = optional(list(string))
        inherit_from_parent = optional(bool, true)
      })), [])
    })
  })
}

variable "instance_name" {
  description = "Name of the instance"
  type        = string
  default     = "test_instance"
}

variable "environment" {
  description = "Environment configuration"
  type = object({
    name         = optional(string, "default")
    unique_name  = optional(string, "default")
    namespace    = optional(string, "default")
    cloud_tags   = optional(map(string), {})
    cluster_code = optional(string, "")
  })
  default = {}
}

variable "inputs" {
  description = "Input references from other modules"
  type = object({
    cloud_account = object({
      attributes = optional(object({
        credentials           = optional(string)
        project_id            = optional(string)
        org_id                = optional(string)
        org_name              = optional(string)
        billing_account       = optional(string)
        quota_project         = optional(string)
        user_project_override = optional(bool)
        region                = optional(string)
        secrets               = optional(list(string), [])
      }), {})
      interfaces = optional(object({}), {})
    })
    parent_folder = object({
      attributes = optional(object({
        folder_id   = optional(string)
        folder_name = optional(string)
        parent      = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}

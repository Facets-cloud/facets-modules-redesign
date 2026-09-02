variable "instance" {
  description = "AWS IAM OIDC provider resource instance."
  type = object({
    kind     = optional(string, "aws_iam_oidc_provider")
    flavor   = optional(string, "gke")
    version  = optional(string, "1.0")
    disabled = optional(bool, false)
    spec = object({
      issuer_url      = optional(string, "")
      client_id_list  = optional(list(string), ["sts.amazonaws.com"])
      thumbprint_list = optional(list(string), [])
      tags            = optional(map(string), {})
    })
  })

  validation {
    condition = (
      var.instance.spec.issuer_url == "" ||
      startswith(var.instance.spec.issuer_url, "https://")
    )
    error_message = "issuer_url must be empty or start with https://."
  }
}

variable "instance_name" {
  description = "Resource name in the Facets blueprint."
  type        = string
}

variable "environment" {
  description = "Environment context."
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "Input references from other modules."
  type = object({
    cloud_account = object({
      attributes = optional(object({
        aws_iam_role = optional(string, "")
        aws_region   = optional(string, "")
        external_id  = optional(string, "")
        session_name = optional(string, "")
      }), {})
      interfaces = optional(object({}), {})
    })
    # @facets/kubernetes-details is delivered as the ATTRIBUTES object itself
    # (resources wire it with output_name: "attributes"), so these are flat.
    # Reading them under a nested .attributes key silently yields "" and fails
    # far downstream as an invalid URL.
    kubernetes_details = object({
      oidc_issuer_url = optional(string, "")
      cluster_name    = optional(string, "")
      project_id      = optional(string, "")
      region          = optional(string, "")
      cloud_provider  = optional(string, "")
    })
  })
}

variable "instance" {
  description = "Cross-cloud VPN configuration."
  type = object({
    kind     = optional(string, "cross_cloud_vpn")
    flavor   = optional(string, "gcp-aws")
    version  = optional(string, "1.0")
    disabled = optional(bool, false)
    spec = object({
      gcp_project_id    = optional(string, "")
      gcp_region        = optional(string, "")
      gcp_vpc_self_link = string
      gcp_cidr          = optional(string, "10.60.0.0/16")
      aws_vpc_id        = string
      aws_cidrs         = optional(list(string), ["10.0.0.0/16", "10.1.0.0/16"])
      db_subnet_ids     = optional(list(string), [])
      existing_vgw_id   = optional(string, "")
      gcp_router_asn    = optional(number, 65001)
      aws_vgw_asn       = optional(number, 64512)
      allowed_tcp_ports = optional(list(number), [5432, 3306])
      mtu               = optional(number, 1436)
      name_prefix       = optional(string, "")
    })
  })

  validation {
    condition     = var.instance.spec.gcp_router_asn != var.instance.spec.aws_vgw_asn
    error_message = "gcp_router_asn and aws_vgw_asn must be different."
  }

  validation {
    condition     = var.instance.spec.mtu >= 1280 && var.instance.spec.mtu <= 1460
    error_message = "mtu must be between 1280 and 1460."
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
    gcp_cloud_account = object({
      attributes = optional(object({
        credentials = optional(string, "")
        project_id  = optional(string, "")
        region      = optional(string, "")
      }), {})
      interfaces = optional(object({}), {})
    })
    aws_cloud_account = object({
      attributes = optional(object({
        aws_iam_role = optional(string, "")
        aws_region   = optional(string, "")
        external_id  = optional(string, "")
        session_name = optional(string, "")
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}

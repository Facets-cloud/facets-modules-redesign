variable "instance" {
  type = object({
    spec = object({
      # Backend service the LB fronts. An @facets/service output-type field: Facets injects the
      # SELECTED service's FULL outputs here (so spec.backend_service.self_links is the list of VM
      # self_links that become the unmanaged-instance-group members). OPTIONAL: greenfield sets it to
      # drive UIG membership; adoption can leave it empty (UIG.instances is ignore_changed, so live
      # members are preserved) when the backend VM isn't (yet) a Facets service.
      backend_service = optional(any, {})

      team = string

      # External (default) or internal managed L7 LB. ForceNew on the FR + backend service.
      lb_scheme = optional(string, "EXTERNAL_MANAGED")

      # Frontend listen port (the global forwarding rule port_range). 443 for HTTPS serving.
      port = optional(number, 443)

      # Backend wire protocol + port. The named_port on the UIG is {backend_port_name: backend_port};
      # the backend service references it by name.
      backend_protocol  = optional(string, "HTTP")
      backend_port      = optional(number, 80)
      backend_port_name = optional(string, "")

      timeout_sec = optional(number, 30)

      # Health check: {protocol(HTTP|HTTPS|TCP), port, request_path}.
      health_check = optional(any, {})

      # If true, create the paired :80 -> :443 redirect stack (extra url-map + http proxy + FR).
      redirect_http = optional(bool, false)

      # Greenfield-only knobs (empty in import):
      #   domains_json       : managed-cert domains [{...}] -> google_compute_managed_ssl_certificate.
      #   routing_rules_json : host/path routing into the url-map. Empty = default_service only.
      domains_json       = optional(string, "[]")
      routing_rules_json = optional(string, "[]")

      # Import-only pins — adopt an existing LB stack 0-change. EMPTY for greenfield.
      #   ip_address            : existing global IP (empty -> create google_compute_global_address).
      #   ssl_certificate_names : JSON array of existing cert names/self_links to REFERENCE (never
      #                           created/imported — e.g. a self-managed wildcard). Empty -> greenfield
      #                           managed cert from domains_json.
      #   *_name                : exact live resource names (empty -> derived from the Facets name).
      imports = optional(any, {})
    })
  })

  validation {
    condition     = length(var.instance.spec.team) > 0
    error_message = "team must be provided and cannot be empty."
  }
  validation {
    condition     = contains(["EXTERNAL_MANAGED", "INTERNAL_MANAGED"], var.instance.spec.lb_scheme)
    error_message = "lb_scheme must be EXTERNAL_MANAGED or INTERNAL_MANAGED."
  }
  validation {
    condition     = contains(["HTTP", "HTTPS"], var.instance.spec.backend_protocol)
    error_message = "backend_protocol must be HTTP or HTTPS."
  }
}

variable "instance_name" {
  type    = string
  default = "load-balancer"
}

variable "environment" {
  type = any
  default = {
    namespace = "default"
  }
}

variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = optional(object({
        credentials    = optional(string)
        project_id     = optional(string)
        project_number = optional(string)
        region         = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    network_details = object({
      attributes = optional(any, {})
      interfaces = optional(any, {})
    })
  })
}

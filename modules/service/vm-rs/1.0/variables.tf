variable "instance" {
  type = object({
    spec = object({
      team         = string
      service_name = optional(string, "")

      # Workload type — mirrors the k8s service.type. Deployment = stateless/fungible;
      # StatefulSet = stable replica identity + per-replica persistent volume.
      type = optional(string, "StatefulSet")

      # Per-replica placement (operational). JSON array of {zone}, one entry per replica
      # (ordinal = array index). Names derive as "{service_name}-{ordinal}". Greenfield + import both set this.
      replicas_json = optional(string, "[]")

      # Import-only adoption pins — needed ONLY to adopt existing VMs 0-change. Empty for greenfield.
      #   network_ips_json    : ordinal-indexed internal IPs to pin (greenfield = ephemeral).
      #   instance_names_json : ordinal-indexed exact names if they don't follow "{service}-{ordinal}".
      imports = optional(any, {})

      machine_type = string

      boot_image       = optional(string, "")
      boot_size_gb     = optional(number, 0)
      boot_disk_type   = optional(string, "pd-balanced")
      boot_auto_delete = optional(bool, true)

      # Per-replica volume template (StatefulSet PVC equivalent). Each entry becomes one
      # independent disk per replica, named "{replica.name}-{suffix}".
      # JSON array of {suffix, size_gb, type, mode, device_name?}.
      data_volumes_json = optional(string, "[]")

      # Regional (replicated) persistent disks — per replica, heterogeneous sizes/zones allowed.
      # JSON array of {replica_name, disk_name, size_gb, type, replica_zones[], device_name, mode}.
      regional_disks_json = optional(string, "[]")

      has_external_ip        = optional(bool, false)
      can_ip_forward         = optional(bool, false)
      public_ptr_domain_name = optional(string, "")

      # cloud_permissions equivalent — empty derives the default compute SA from the input.
      service_account_email       = optional(string, "")
      service_account_scopes_json = optional(string, "[]")

      # env / metadata.
      metadata_json = optional(string, "{}")
      tags_json     = optional(string, "[]")

      automatic_restart   = optional(bool, true)
      on_host_maintenance = optional(string, "MIGRATE")
      preemptible         = optional(bool, false)
      provisioning_model  = optional(string, "STANDARD")

      shielded_enabled            = optional(bool, true)
      enable_secure_boot          = optional(bool, false)
      enable_vtpm                 = optional(bool, true)
      enable_integrity_monitoring = optional(bool, true)

      deletion_protection = optional(bool, false)
    })
  })

  validation {
    condition     = length(var.instance.spec.team) > 0
    error_message = "team must be provided and cannot be empty."
  }
  validation {
    condition     = contains(["Deployment", "StatefulSet"], var.instance.spec.type)
    error_message = "type must be Deployment or StatefulSet."
  }
}

variable "instance_name" {
  type    = string
  default = "service"
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

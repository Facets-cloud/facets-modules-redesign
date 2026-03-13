# Managed Instance Group — maintains a fleet of identical VMs from the instance template.
# target_size is intentionally omitted here; the autoscaler controls instance count.
resource "google_compute_instance_group_manager" "this" {
  name               = local.vm_name
  project            = local.project_id
  zone               = local.zone
  base_instance_name = local.vm_name
  # When stateful=true there is no autoscaler; target_size controls the fixed instance count.
  target_size = lookup(var.instance.spec, "stateful", false) ? lookup(var.instance.spec.runtime.autoscaling, "min", 1) : null

  version {
    instance_template = google_compute_instance_template.this.id
  }

  # Rolling update policy: replace instances one at a time with zero downtime.
  # replacement_method must be RECREATE when stateful disks are configured (GCP API requirement).
  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    replacement_method    = lookup(var.instance.spec, "stateful", false) ? "RECREATE" : "SUBSTITUTE"
    max_surge_fixed       = lookup(var.instance.spec, "stateful", false) ? 0 : 1
    max_unavailable_fixed = lookup(var.instance.spec, "stateful", false) ? 1 : 0
  }

  # Preserve the boot disk across instance recreation when stateful=true.
  # delete_rule = "NEVER" ensures the disk is detached (not deleted) when an
  # instance is removed from the group, and reattached when it comes back.
  dynamic "stateful_disk" {
    for_each = lookup(var.instance.spec, "stateful", false) ? [1] : []
    content {
      device_name = "boot"
      delete_rule = "NEVER"
    }
  }

  # Named ports — used by load balancers and health checks to route traffic by port name
  dynamic "named_port" {
    for_each = try(var.instance.spec.runtime.ports, {})
    content {
      name = named_port.key
      port = named_port.value.port
    }
  }

  # Auto-healing: replace instances that fail the health check after initial_delay
  dynamic "auto_healing_policies" {
    for_each = local.health_check_enabled ? [1] : []
    content {
      health_check      = google_compute_health_check.this[0].id
      initial_delay_sec = try(var.instance.spec.runtime.health_checks.initial_delay, 300)
    }
  }

  # Do not block Terraform apply waiting for all instances to become healthy
  wait_for_instances = false
}

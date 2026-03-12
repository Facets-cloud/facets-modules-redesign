# Instance template defines the VM configuration applied to every MIG instance.
# A new template is created on any config change; the MIG rolls it out via update_policy.
resource "google_compute_instance_template" "this" {
  # Datetime suffix ensures a globally unique name on every new template creation.
  # ignore_changes on name prevents perpetual replacement from timestamp drift on re-plans.
  name         = "${local.vm_name}-${formatdate("YYMMDDhhmmss", timestamp())}"
  machine_type = var.instance.spec.machine.machine_type
  project      = local.project_id

  labels = local.all_labels
  tags   = local.network_tags

  # Startup script and env key-value pairs injected as GCP instance metadata
  metadata = local.instance_metadata

  # Boot disk — sourced from the configured OS image.
  # device_name is explicitly set so the stateful_disk block in the MIG can reference it.
  # auto_delete is false when stateful=true so the disk survives instance removal.
  disk {
    source_image = var.instance.spec.boot_disk.image
    auto_delete  = lookup(var.instance.spec, "stateful", false) ? false : true
    boot         = true
    device_name  = "boot"
    disk_size_gb = lookup(var.instance.spec.boot_disk, "size_gb", 20)
    disk_type    = lookup(var.instance.spec.boot_disk, "type", "pd-balanced")
  }

  network_interface {
    subnetwork = local.subnetwork

    # Attach ephemeral external IP when assign_external_ip is true
    dynamic "access_config" {
      for_each = local.assign_external_ip ? [1] : []
      content {}
    }
  }

  # Attach the dedicated service account with full cloud-platform scope
  service_account {
    email  = google_service_account.this.email
    scopes = ["cloud-platform"]
  }

  # Required so MIG can create the new template before destroying the old one
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name]
  }
}

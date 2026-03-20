module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 63
  resource_name = var.instance_name
  resource_type = "compute_engine"
}

resource "google_compute_instance" "this" {
  name         = local.vm_name
  machine_type = local.machine_type
  zone         = local.zone
  project      = local.project_id

  tags = local.tags

  boot_disk {
    initialize_params {
      image = local.disk_image
      size  = local.disk_size_gb
      type  = local.disk_type
    }
  }

  network_interface {
    network    = local.network
    subnetwork = local.subnetwork != "" ? local.subnetwork : null

    dynamic "access_config" {
      for_each = local.assign_public_ip ? [1] : []
      content {
        # ephemeral public IP
      }
    }
  }

  metadata_startup_script = local.startup_script != "" ? local.startup_script : null

  dynamic "service_account" {
    for_each = local.sa_email != "" ? [local.sa_email] : []
    content {
      email  = service_account.value
      scopes = local.sa_scopes
    }
  }

  # Allow Terraform to stop the instance when changing properties that require it
  allow_stopping_for_update = true
}

resource "google_compute_firewall" "open_ports" {
  for_each = local.open_ports

  name    = substr("${local.vm_name}-${each.key}", 0, 63)
  network = local.network
  project = local.project_id

  allow {
    protocol = try(each.value.protocol, "tcp")
    ports    = [tostring(each.value.port)]
  }

  source_ranges = try(each.value.source_ranges, ["0.0.0.0/0"])
  target_tags   = [local.vm_name]
}

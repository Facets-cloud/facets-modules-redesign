locals {
  # Output attributes — instance group and service account identifiers
  output_attributes = {
    instance_group_name    = google_compute_instance_group_manager.this.name
    instance_template_name = google_compute_instance_template.this.name
    resource_name          = var.instance_name
    resource_type          = "gcp-vm"
    zone                   = local.zone
    service_account_email  = google_service_account.this.email
  }

  # Output interfaces — expose SSH port; host is the MIG self_link since
  # there is no single static IP in a managed instance group
  output_interfaces = {
    ssh = {
      host      = google_compute_instance_group_manager.this.self_link
      port      = 22
      port_name = "ssh"
      name      = google_compute_instance_group_manager.this.name
      username  = ""
      password  = ""
      secrets   = []
    }
  }
}

output "instance" {
  value = {
    attributes = local.output_attributes
    interfaces = local.output_interfaces
  }
}

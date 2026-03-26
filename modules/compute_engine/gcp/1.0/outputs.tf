locals {
  output_interfaces = {}

  output_attributes = {
    instance_name = google_compute_instance.this.name
    instance_id   = google_compute_instance.this.instance_id
    self_link     = google_compute_instance.this.self_link
    zone          = google_compute_instance.this.zone
    machine_type  = google_compute_instance.this.machine_type
    project_id    = local.project_id
    internal_ip   = google_compute_instance.this.network_interface[0].network_ip
    external_ip   = local.assign_public_ip ? try(google_compute_instance.this.network_interface[0].access_config[0].nat_ip, "") : ""
  }
}

locals {
  spec = var.instance.spec

  # Cloud account outputs (project, credentials)
  project_id = coalesce(
    try(var.inputs.cloud_account.attributes.project_id, null),
    try(var.inputs.cloud_account.attributes.project, null)
  )

  # Region from network module (consistent with gcp-bastion)
  region = var.inputs.network_details.attributes.region

  # VM identity
  vm_name = var.instance_name

  # Compute spec
  machine_type = try(local.spec.machine_type, "e2-standard-2")
  zone         = try(local.spec.zone, "asia-south1-a")

  # Boot disk
  disk_image   = try(local.spec.boot_disk.image, "debian-cloud/debian-11")
  disk_size_gb = try(local.spec.boot_disk.size_gb, 50)
  disk_type    = try(local.spec.boot_disk.type, "pd-ssd")

  # Network — resolve from network module, with optional spec overrides
  network_details   = var.inputs.network_details.attributes
  requested_network = trimspace(try(local.spec.network.vpc_name, ""))
  requested_subnet  = trimspace(try(local.spec.network.subnetwork, ""))

  network    = local.requested_network != "" ? local.requested_network : local.network_details.vpc_self_link
  subnetwork = local.requested_subnet != "" ? local.requested_subnet : try(local.network_details.private_subnet_name, "")

  assign_public_ip = try(local.spec.network.assign_public_ip, true)

  # Startup script
  startup_script = try(local.spec.startup_script, "")

  # Network tags — always include the vm_name tag so firewall rules can target it
  tags = concat(try(local.spec.tags, []), [local.vm_name])

  # Firewall port rules
  open_ports = try(local.spec.open_ports, {})

  # Service account
  sa_email  = try(local.spec.service_account.email, "")
  sa_scopes = try(local.spec.service_account.scopes, ["https://www.googleapis.com/auth/cloud-platform"])
}

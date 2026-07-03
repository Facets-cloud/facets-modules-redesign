locals {
  spec        = var.instance.spec
  ca_attrs    = var.inputs.cloud_account.attributes
  gcp_project = local.ca_attrs.project_id

  # Network/subnetwork from the network_details input (default VPC for these VMs).
  net_attrs  = var.inputs.network_details.attributes
  network    = lookup(local.net_attrs, "vpc_id", "default")
  subnetwork = lookup(local.net_attrs, "private_subnet_id", "default")

  # Default compute SA derived from the cloud_account input (project_number). Override only for custom SAs.
  default_sa = "${local.ca_attrs.project_number}-compute@developer.gserviceaccount.com"
  sa_email   = lookup(local.spec, "service_account_email", "") != "" ? local.spec.service_account_email : local.default_sa

  service_name = lookup(local.spec, "service_name", "") != "" ? local.spec.service_name : var.instance_name

  # Operational placement: [{zone}], ordinal = index.
  replicas_raw = jsondecode(lookup(local.spec, "replicas_json", "[]"))

  # Import-only pins (empty for greenfield): pinned IPs + exact names, ordinal-indexed.
  imports_obj  = lookup(local.spec, "imports", {})
  import_ips   = jsondecode(lookup(local.imports_obj, "network_ips_json", "[]"))
  import_names = jsondecode(lookup(local.imports_obj, "instance_names_json", "[]"))

  # Resolve: name = import pin else "{service}-{ordinal}"; zone operational; IP = import pin else ephemeral.
  replicas = [for i, r in local.replicas_raw : {
    name       = i < length(local.import_names) ? local.import_names[i] : "${local.service_name}-${i}"
    zone       = r.zone
    network_ip = i < length(local.import_ips) ? local.import_ips[i] : ""
  }]

  # Per-replica volume template (StatefulSet): [{suffix, size_gb, type, mode, device_name?}].
  data_volumes = jsondecode(lookup(local.spec, "data_volumes_json", "[]"))

  # Expand template × replicas → one disk per (replica, volume). Stable name "{replica}-{suffix}".
  disks = flatten([
    for r in local.replicas : [
      for v in local.data_volumes : {
        key     = "${r.name}-${v.suffix}"
        replica = r.name
        zone    = r.zone
        size_gb = v.size_gb
        type    = lookup(v, "type", "pd-balanced")
        # Actual disk name — defaults to "{replica}-{suffix}", overridable for non-conventional
        # live disk names (e.g. an existing disk with a typo or a bespoke name).
        disk_name   = lookup(v, "disk_name", "${r.name}-${v.suffix}")
        device_name = lookup(v, "device_name", "${r.name}-${v.suffix}")
        mode        = lookup(v, "mode", "READ_WRITE")
      }
    ]
  ])

  # Regional (replicated) PD — per-replica, heterogeneous sizes/zones. Each entry binds to a replica
  # by replica_name. Region is derived from the first replica zone.
  regional_disks = jsondecode(lookup(local.spec, "regional_disks_json", "[]"))

  scopes   = jsondecode(lookup(local.spec, "service_account_scopes_json", "[]"))
  metadata = jsondecode(lookup(local.spec, "metadata_json", "{}"))
  tags     = jsondecode(lookup(local.spec, "tags_json", "[]"))
}

# Regional replicated persistent disks (StatefulSet across zones). prevent_destroy: they carry data.
resource "google_compute_region_disk" "data" {
  for_each      = { for d in local.regional_disks : d.disk_name => d }
  name          = each.value.disk_name
  project       = local.gcp_project
  region        = join("-", slice(split("-", each.value.replica_zones[0]), 0, 2))
  replica_zones = each.value.replica_zones
  size          = each.value.size_gb
  type          = lookup(each.value, "type", "pd-balanced")

  lifecycle {
    prevent_destroy = true
    # replica_zones: live stores full-URL zones (order can differ) — normalization, ignore it.
    # description: hand-rolled disks carry a free-text description; it's ForceNew, so leaving it
    # unset would replace the disk on import. Not modeled here → ignore so adoption is 0-change.
    ignore_changes = [snapshot, labels, replica_zones, description]
  }
}

# Per-replica persistent volumes (StatefulSet). prevent_destroy: they carry data.
resource "google_compute_disk" "data" {
  for_each = { for d in local.disks : d.key => d }
  name     = each.value.disk_name
  project  = local.gcp_project
  zone     = each.value.zone
  size     = each.value.size_gb
  type     = each.value.type

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [image, snapshot, labels]
  }
}

# One VM per replica, stable identity (each.value.name), pinned zone + internal IP.
resource "google_compute_instance" "vm" {
  for_each = { for r in local.replicas : r.name => r }

  # NOTE: intentionally NO depends_on the disks. The regional disk attach uses a constructed source
  # path (not a resource reference), so there is no value dependency; adding an explicit depends_on
  # would make the VM's import fail whenever the disks are imported in the same plan ("Cannot import
  # to non-existent resource address"). For greenfield, the region disks are quick to materialize and
  # the attach tolerates eventual consistency; adoption (the primary use) needs the decoupling.

  name                = each.value.name
  project             = local.gcp_project
  zone                = each.value.zone
  machine_type        = local.spec.machine_type
  deletion_protection = lookup(local.spec, "deletion_protection", false)
  # VPN / router / NAT VMs forward traffic not destined for themselves → can_ip_forward=true.
  can_ip_forward = lookup(local.spec, "can_ip_forward", false)

  boot_disk {
    auto_delete = lookup(local.spec, "boot_auto_delete", true)
    initialize_params {
      image = lookup(local.spec, "boot_image", "")
      size  = lookup(local.spec, "boot_size_gb", 10)
      type  = lookup(local.spec, "boot_disk_type", "pd-balanced")
    }
  }

  # Attach this replica's volumes (StatefulSet — stable per-replica disks).
  dynamic "attached_disk" {
    for_each = { for d in local.disks : d.key => d if d.replica == each.value.name }
    content {
      source      = google_compute_disk.data[attached_disk.key].self_link
      device_name = attached_disk.value.device_name
      mode        = attached_disk.value.mode
    }
  }

  # Regional replicated disks attached to this replica. Source is a constructed path (NOT a
  # reference to google_compute_region_disk.data[*].self_link): the resource-level depends_on below
  # preserves greenfield create-ordering, while decoupling the attribute keeps the instance
  # importable independently of disk state (a self_link reference would be unknown-until-applied and
  # block the import plan from resolving this resource).
  dynamic "attached_disk" {
    for_each = { for d in local.regional_disks : d.disk_name => d if d.replica_name == each.value.name }
    content {
      source      = "projects/${local.gcp_project}/regions/${join("-", slice(split("-", attached_disk.value.replica_zones[0]), 0, 2))}/disks/${attached_disk.value.disk_name}"
      device_name = lookup(attached_disk.value, "device_name", attached_disk.key)
      mode        = lookup(attached_disk.value, "mode", "READ_WRITE")
    }
  }

  network_interface {
    network = local.network
    # Subnetwork is region-scoped. The network_details input carries the network's home-region
    # default subnet; for a replica in that same region we use it verbatim (so existing imports stay
    # byte-identical). A replica in another region derives that region's default subnet instead.
    subnetwork = (
      join("-", slice(split("-", each.value.zone), 0, 2)) == lookup(local.net_attrs, "region", "us-central1")
      ? local.subnetwork
      : "projects/${local.gcp_project}/regions/${join("-", slice(split("-", each.value.zone), 0, 2))}/subnetworks/default"
    )
    network_ip = lookup(each.value, "network_ip", "") != "" ? each.value.network_ip : null

    dynamic "access_config" {
      for_each = lookup(local.spec, "has_external_ip", false) ? [1] : []
      content {
        # Reverse-DNS PTR on the external IP (mail servers etc. set this). Empty = no PTR (the common case).
        public_ptr_domain_name = lookup(local.spec, "public_ptr_domain_name", "") != "" ? local.spec.public_ptr_domain_name : null
      }
    }
  }

  service_account {
    email  = local.sa_email
    scopes = local.scopes
  }

  metadata = local.metadata
  tags     = local.tags

  scheduling {
    automatic_restart   = lookup(local.spec, "automatic_restart", true)
    on_host_maintenance = lookup(local.spec, "on_host_maintenance", "MIGRATE")
    preemptible         = lookup(local.spec, "preemptible", false)
    provisioning_model  = lookup(local.spec, "provisioning_model", "STANDARD")
  }

  # Shielded VM — dynamic: some boot images (non-UEFI_COMPATIBLE) don't support it, so the live
  # VM has no shielded_instance_config block. shielded_enabled=false omits it entirely (0-change
  # adoption for those); default true keeps it for the majority that are shielded.
  dynamic "shielded_instance_config" {
    for_each = lookup(local.spec, "shielded_enabled", true) ? [1] : []
    content {
      enable_secure_boot          = lookup(local.spec, "enable_secure_boot", false)
      enable_vtpm                 = lookup(local.spec, "enable_vtpm", true)
      enable_integrity_monitoring = lookup(local.spec, "enable_integrity_monitoring", true)
    }
  }

  lifecycle {
    ignore_changes = [
      labels,
      # Ignore the WHOLE metadata, not just ssh-keys: these hand-rolled VMs set metadata once
      # (startup scripts, and in some cases plaintext secrets like DB passwords). A read-only import
      # must not pull those into the blueprint, and metadata isn't actively managed here. Greenfield
      # still applies metadata_json at create; it's ignored on drift thereafter.
      metadata,
      boot_disk[0].initialize_params[0].image,
      # Boot disk size can diverge per replica in an adopted fleet (hand-rolled VMs
      # were grown independently); greenfield still provisions at boot_size_gb.
      boot_disk[0].initialize_params[0].size,
      # Provider-computed defaults whose live value equals the GCP default; omitting
      # them in config reads as removal and forces replacement on import. Ignoring keeps
      # greenfield letting the provider choose and makes adoption 0-change.
      key_revocation_action_type,
      network_interface[0].nic_type,
      # CPU features (threads_per_core, nested-virt, etc.) are set-once at create and not modeled
      # here; the live block reads into state and would otherwise plan as removal.
      advanced_machine_features,
    ]
  }
}

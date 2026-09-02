terraform {
  required_version = ">= 1.0"
}

resource "google_kms_key_ring" "this" {
  name     = var.instance.spec.keyring_name
  project  = var.inputs.project.attributes.project_id
  location = local.location

  lifecycle {
    precondition {
      condition     = length(local.unknown_service_agents) == 0
      error_message = "Unknown gcp_kms service_agents short name(s): ${join(", ", local.unknown_service_agents)}. Allowed service_agents: ${join(", ", sort(keys(local.service_agent_configs)))}."
    }
  }
}

resource "google_kms_crypto_key" "keys" {
  for_each = local.keys_by_name

  name            = each.key
  key_ring        = google_kms_key_ring.this.id
  purpose         = lookup(each.value, "purpose", "ENCRYPT_DECRYPT")
  rotation_period = lookup(each.value, "rotation_period", "7776000s")

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = lookup(each.value, "protection_level", "SOFTWARE")
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key_iam_member" "service_agents" {
  for_each = local.key_grants_by_id

  crypto_key_id = google_kms_crypto_key.keys[each.value.key_name].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  member = "serviceAccount:${format(local.service_agent_configs[each.value.service_agent].email_pattern, each.value.project_number)}"

  # The member string is intentionally derived from the curated service-agent
  # pattern map so existing IAM members stay known at plan time when new project
  # grants are added. Keep an explicit ordering edge because we no longer read
  # google_project_service_identity.service_agents[*].email in this resource.
  depends_on = [google_project_service_identity.service_agents]
}

resource "google_project_service_identity" "service_agents" {
  provider = google-beta
  for_each = local.service_identity_grants_by_id

  project = each.value.project_number
  service = local.service_agent_configs[each.value.service_agent].service
}

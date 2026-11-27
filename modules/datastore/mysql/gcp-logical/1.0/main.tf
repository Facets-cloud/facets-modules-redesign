resource "google_sql_database" "logical" {
  for_each = toset(nonsensitive(jsondecode(var.instance.spec.databases_json)))
  name     = each.key
  instance = var.instance.spec.cloud_sql_instance
  project  = var.inputs.cloud_account.attributes.project_id
}

resource "google_sql_user" "shared" {
  for_each        = toset(nonsensitive(keys(var.instance.spec.managed_users)))
  name            = each.key
  instance        = var.instance.spec.cloud_sql_instance
  project         = var.inputs.cloud_account.attributes.project_id
  host            = var.instance.spec.managed_users[each.key].host
  password        = sensitive(lookup(jsondecode(var.instance.spec.canonical_passwords_json), each.key, ""))
  deletion_policy = "ABANDON"
  lifecycle {
    precondition {
      condition     = length(lookup(jsondecode(var.instance.spec.canonical_passwords_json), each.key, "")) > 0
      error_message = "Every managed user requires a canonical password."
    }
  }
}

resource "terraform_data" "credential_contract" {
  lifecycle {
    precondition {
      condition     = alltrue([for name in local.declared_user_names : length(lookup(jsondecode(var.instance.spec.canonical_passwords_json), name, "")) > 0])
      error_message = "Every declared logical user requires a canonical password."
    }
  }
}

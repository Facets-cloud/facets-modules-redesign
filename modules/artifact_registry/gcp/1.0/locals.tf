locals {
  project_id        = var.inputs.project.attributes.project_id
  repository_id     = var.instance.spec.repository_id
  location          = lookup(var.instance.spec, "location", "asia-south1")
  format            = lookup(var.instance.spec, "format", "DOCKER")
  description       = lookup(var.instance.spec, "description", "")
  kms_key_name      = lookup(var.instance.spec, "kms_key_name", "artifacts")
  cleanup_policies  = lookup(var.instance.spec, "cleanup_policies", [])
  immutable_tags    = lookup(var.instance.spec, "immutable_tags", false)
  repository_url    = "${local.location}-docker.pkg.dev/${local.project_id}/${local.repository_id}"
  kms_input_present = lookup(var.inputs, "kms", null) != null
}

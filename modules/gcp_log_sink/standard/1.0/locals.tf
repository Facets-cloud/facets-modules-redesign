locals {
  location          = lookup(var.instance.spec, "location", "asia-south1")
  retention_days    = lookup(var.instance.spec, "retention_days", 400)
  retention_seconds = local.retention_days * 86400
  retention_locked  = lookup(var.instance.spec, "lock_retention", false)
  filter            = lookup(var.instance.spec, "filter", "")
  kms_key_name      = lookup(var.instance.spec, "kms_key_name", "audit")
}

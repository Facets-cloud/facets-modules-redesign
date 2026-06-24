locals {
  # ── Spec shortcuts ─────────────────────────────────────────────────────────
  storage_config    = var.instance.spec.storage_config
  workload_identity = var.instance.spec.workload_identity

  # ── Storage configuration ──────────────────────────────────────────────────
  container_name    = local.storage_config.container_name
  account_tier      = local.storage_config.account_tier
  replication_type  = local.storage_config.replication_type
  enable_versioning = local.storage_config.enable_versioning
  retention_days    = local.storage_config.retention_days
  has_retention     = local.retention_days > 0

  # ── Workload identity / Kubernetes service account ─────────────────────────
  k8s_sa_namespace = local.workload_identity.service_account_namespace
  k8s_sa_name      = local.workload_identity.service_account_name

  # ── Loki query timeout (from optional nested object) ───────────────────────
  query_timeout = var.instance.spec.loki_config != null ? var.instance.spec.loki_config.query_timeout : 60

  # ── AKS cluster attributes (via lookup for safe optional access) ───────────
  aks_attributes      = lookup(var.inputs.aks_cluster, "attributes", {})
  resource_group_name = lookup(local.aks_attributes, "resource_group_name", "")
  location            = lookup(local.aks_attributes, "cluster_location", "")
  oidc_issuer_url     = lookup(local.aks_attributes, "oidc_issuer_url", "")

  # ── Storage account name: 3-24 chars, globally unique, lowercase alphanumeric only ──
  # Azure storage account names cannot contain hyphens or underscores.
  storage_account_name_raw = lower(
    replace(replace("${var.environment.unique_name}${var.instance_name}", "-", ""), "_", "")
  )
  storage_account_name = substr(local.storage_account_name_raw, 0, 24)

  # ── Managed identity resource name ────────────────────────────────────────
  identity_name = "loki-id-${var.environment.unique_name}-${var.instance_name}"

  # ── Federated credential name (must be unique per managed identity) ────────
  federated_credential_name = "${var.instance_name}-loki-fed-cred"

  # ── Tags ───────────────────────────────────────────────────────────────────
  all_tags = merge(
    var.environment.cloud_tags,
    var.instance.spec.tags,
    {
      resource_type = "loki_blob"
      resource_name = var.instance_name
      flavor        = "azure"
    }
  )

  # ── Azure Blob endpoint suffix (used in Loki Helm chart config) ───────────
  endpoint_suffix = "core.windows.net"
}

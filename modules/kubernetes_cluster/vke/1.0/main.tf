# Vultr Kubernetes Engine (VKE) Cluster Module
# Creates a VKE cluster with a default node pool and exposes Kubernetes + Helm providers.

locals {
  # When a VPC is wired, the cluster region must match the VPC's region; otherwise fall
  # back to the linked cloud account's default region. VKE supports the original VPC only.
  region = coalesce(try(var.inputs.network.attributes.region, null), var.inputs.vultr_cloud_account.attributes.region)
  vpc_id = try(var.inputs.network.attributes.vpc_id, null)

  autoscaler_enabled = try(var.instance.spec.default_pool.autoscaler.enabled, false)

  # Parse the cluster kubeconfig (base64-encoded YAML) to derive provider connection
  # details. Vultr VKE authenticates with client certificate/key (not a bearer token).
  # At plan time these resolve to unknown values, which is expected.
  kubeconfig_decoded     = try(yamldecode(base64decode(vultr_kubernetes.cluster.kube_config)), {})
  kubeconfig_server      = try(local.kubeconfig_decoded["clusters"][0]["cluster"]["server"], "")
  cluster_ca_certificate = try(base64decode(local.kubeconfig_decoded["clusters"][0]["cluster"]["certificate-authority-data"]), "")
  client_certificate     = try(base64decode(local.kubeconfig_decoded["users"][0]["user"]["client-certificate-data"]), "")
  client_key             = try(base64decode(local.kubeconfig_decoded["users"][0]["user"]["client-key-data"]), "")

  # Prefer the fully-qualified API server URL from the kubeconfig; fall back to the
  # cluster endpoint attribute with the standard https scheme and port.
  cluster_endpoint = local.kubeconfig_server != "" ? local.kubeconfig_server : "https://${vultr_kubernetes.cluster.endpoint}:6443"
}

module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 32
  resource_name   = var.instance_name
  resource_type   = "kubernetes_cluster"
  globally_unique = true
}

resource "vultr_kubernetes" "cluster" {
  label            = module.name.name
  region           = local.region
  version          = var.instance.spec.k8s_version
  ha_controlplanes = var.instance.spec.high_availability
  enable_firewall  = var.instance.spec.enable_firewall

  # Optional VPC placement (null when no network is wired).
  vpc_id = local.vpc_id

  # VKE requires at least one node pool defined inline at cluster creation.
  node_pools {
    label         = "default"
    plan          = var.instance.spec.default_pool.node_type
    node_quantity = var.instance.spec.default_pool.node_count
    auto_scaler   = local.autoscaler_enabled
    min_nodes     = local.autoscaler_enabled ? var.instance.spec.default_pool.autoscaler.min : null
    max_nodes     = local.autoscaler_enabled ? var.instance.spec.default_pool.autoscaler.max : null
  }

  lifecycle {
    # When autoscaling is enabled, the node count drifts and should not be reconciled.
    ignore_changes = [node_pools[0].node_quantity]
  }
}

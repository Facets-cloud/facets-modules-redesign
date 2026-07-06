# Linode Kubernetes Engine (LKE) Cluster Module
# Creates an LKE cluster with a default node pool and exposes Kubernetes + Helm providers.

locals {
  # When a VPC is wired, the cluster region must match the VPC's region; otherwise fall
  # back to the linked cloud account's default region.
  region = coalesce(try(var.inputs.network.attributes.region, null), var.inputs.linode_cloud_account.attributes.region)

  # Optional VPC placement for cluster nodes (numbers expected by the provider).
  vpc_id    = try(tonumber(var.inputs.network.attributes.vpc_id), null)
  subnet_id = try(tonumber(var.inputs.network.attributes.subnet_id), null)

  autoscaler_enabled = try(var.instance.spec.default_pool.autoscaler.enabled, false)

  # Parse the cluster kubeconfig (base64-encoded) to derive provider connection details.
  # At plan time these resolve to unknown values, which is expected.
  kubeconfig_decoded     = try(yamldecode(base64decode(linode_lke_cluster.cluster.kubeconfig)), {})
  cluster_ca_certificate = try(base64decode(local.kubeconfig_decoded["clusters"][0]["cluster"]["certificate-authority-data"]), "")
  cluster_token          = try(local.kubeconfig_decoded["users"][0]["user"]["token"], "")
}

module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 32
  resource_name   = var.instance_name
  resource_type   = "kubernetes_cluster"
  globally_unique = true
}

resource "linode_lke_cluster" "cluster" {
  label       = module.name.name
  region      = local.region
  k8s_version = var.instance.spec.k8s_version
  tags        = ["facets", var.environment.unique_name]

  # Optional VPC placement (both null when no network is wired).
  vpc_id    = local.vpc_id
  subnet_id = local.subnet_id

  control_plane {
    high_availability  = var.instance.spec.high_availability
    audit_logs_enabled = var.instance.spec.audit_logs_enabled

    # Optional API-server IP allow-list. Only enabled when CIDRs are provided,
    # otherwise the API server stays open (required for the deployment runner to reach it).
    dynamic "acl" {
      for_each = length(var.instance.spec.api_server_allowed_cidrs) > 0 ? [1] : []
      content {
        enabled = true
        addresses {
          ipv4 = var.instance.spec.api_server_allowed_cidrs
        }
      }
    }
  }

  pool {
    type  = var.instance.spec.default_pool.node_type
    count = var.instance.spec.default_pool.node_count

    dynamic "autoscaler" {
      for_each = local.autoscaler_enabled ? [1] : []
      content {
        min = var.instance.spec.default_pool.autoscaler.min
        max = var.instance.spec.default_pool.autoscaler.max
      }
    }
  }

  lifecycle {
    # When autoscaling is enabled, the node count drifts and should not be reconciled.
    ignore_changes = [pool[0].count]
  }
}

# MinIO Object Storage Module - Local Variables
# KubeBlocks v1.0

locals {
  # Cluster configuration
  cluster_name = var.instance_name
  namespace    = try(var.instance.spec.namespace_override, "") != "" ? var.instance.spec.namespace_override : var.environment.namespace
  replicas     = var.instance.spec.mode == "standalone" ? 1 : lookup(var.instance.spec, "replicas", 4)

  # HA settings
  ha_enabled               = var.instance.spec.mode == "distributed"
  enable_pod_anti_affinity = local.ha_enabled # Enable pod anti-affinity for distributed deployments

  # Get node pool details from input
  node_pool_input  = lookup(var.inputs, "node_pool", {})
  node_pool_attrs  = lookup(local.node_pool_input, "attributes", {})
  node_selector    = lookup(local.node_pool_attrs, "node_selector", {})
  node_pool_taints = lookup(local.node_pool_attrs, "taints", [])

  # Convert taints to tolerations
  tolerations = [
    for taint in local.node_pool_taints : {
      key      = taint.key
      operator = "Equal"
      value    = taint.value
      effect   = taint.effect
    }
  ]

  # MinIO version
  minio_version = var.instance.spec.minio_version

  # KubeBlocks MinIO addon version
  release_version = "1.0.0"

  # Buckets to create on initialization
  buckets_to_create = lookup(var.instance.spec, "buckets", "")

  # Credentials from secret
  minio_root_user     = try(data.kubernetes_secret.minio_credentials.data["username"], "admin")
  minio_root_password = try(data.kubernetes_secret.minio_credentials.data["password"], "")

  # Validate password exists
  password_is_valid = local.minio_root_password != "" && length(local.minio_root_password) > 0

  # MinIO API endpoint (port 9000)
  api_host = "${local.cluster_name}-minio.${local.namespace}.svc.cluster.local"
  api_port = 9000

  # MinIO Console endpoint (port 9001)
  console_host = local.api_host
  console_port = 9001

  # S3-compatible endpoint URL
  s3_endpoint = "http://${local.api_host}:${local.api_port}"

  # Console URL
  console_url = "http://${local.console_host}:${local.console_port}"

  # Access credentials
  access_key = local.minio_root_user
  secret_key = local.minio_root_password
}

# Cassandra Cluster Module - Local Variables
# k8ssandra-operator (K8ssandraCluster CR)

locals {
  # Cluster configuration
  # Name limit 40: cass-operator derives StatefulSet/pod names as
  # <cluster>-<dc>-<rack>-sts-<n>, which must stay inside k8s 63-char limits.
  cluster_name = module.name.name
  namespace    = try(var.instance.spec.namespace_override, "") != "" ? var.instance.spec.namespace_override : var.environment.namespace
  replicas     = var.instance.spec.mode == "standalone" ? 1 : lookup(var.instance.spec, "replicas", 3)

  # Single-DC topology; the datacenter name feeds service/pod naming
  datacenter = "dc1"

  # HA settings
  ha_config              = lookup(var.instance.spec, "high_availability", {})
  soft_pod_anti_affinity = lookup(local.ha_config, "soft_pod_anti_affinity", true)

  # Get node pool details from input
  node_pool_input  = lookup(var.inputs, "node_pool", {})
  node_pool_attrs  = lookup(local.node_pool_input, "attributes", {})
  node_selector    = lookup(local.node_pool_attrs, "node_selector", {})
  node_pool_taints = lookup(local.node_pool_attrs, "taints", [])

  # Convert taints from {key, value, effect} to tolerations format
  tolerations = [
    for taint in local.node_pool_taints : {
      key      = taint.key
      operator = "Equal"
      value    = taint.value
      effect   = taint.effect
    }
  ]

  # Superuser credentials: the operator generates the secret
  # "<cluster_name>-superuser" (keys: username, password) when no
  # superuserSecretRef is set on the K8ssandraCluster CR.
  superuser_secret_name = "${local.cluster_name}-superuser"
  admin_username        = try(data.kubernetes_secret_v1.superuser.data["username"], "")
  admin_password        = try(data.kubernetes_secret_v1.superuser.data["password"], "")
  password_is_valid     = local.admin_password != "" && length(local.admin_password) > 0

  # CQL contact point: cass-operator creates "<cluster>-<dc>-service"
  # fronting all Cassandra nodes on 9042.
  service_name = "${local.cluster_name}-${local.datacenter}-service"
  contact_host = "${local.service_name}.${local.namespace}.svc"
  cql_port     = 9042
  endpoint     = "${local.contact_host}:${local.cql_port}"

  endpoints = {
    "0" = local.endpoint
  }

  connection_string = local.password_is_valid ? "cassandra://${local.admin_username}:${local.admin_password}@${local.endpoint}" : null
}

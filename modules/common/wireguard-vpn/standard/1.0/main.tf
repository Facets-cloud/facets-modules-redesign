locals {
  spec                = lookup(var.instance, "spec", {})
  namespace           = lookup(local.spec, "namespace", "") != "" ? lookup(local.spec, "namespace", "") : var.environment.namespace
  enable_ip_forward   = lookup(local.spec, "enable_ip_forward", true)
  service_annotations = lookup(local.spec, "service_annotations", {})
  service_type        = "LoadBalancer" # Fixed service type for Wireguard VPN

  # Get kubernetes details to determine cloud provider
  kubernetes_details_input = lookup(var.inputs, "kubernetes_details", {})
  kubernetes_details_attrs = local.kubernetes_details_input
  cloud_provider           = lookup(local.kubernetes_details_attrs, "cloud_provider", "")

  # Automatically determine MTU based on cloud provider
  # GCP requires 1380, others use 1500
  mtu = local.cloud_provider == "GCP" ? "1380" : "1500"

  # Get node pool details from input
  node_pool_input  = lookup(var.inputs, "node_pool", {})
  node_pool_attrs  = lookup(local.node_pool_input, "attributes", {})
  node_selector    = lookup(local.node_pool_attrs, "node_selector", {})
  node_pool_taints = lookup(local.node_pool_attrs, "taints", [])

  # Get wireguard operator details
  wireguard_operator_input = lookup(var.inputs, "wireguard_operator", {})
  wireguard_operator_attrs = lookup(local.wireguard_operator_input, "attributes", {})
  operator_namespace       = lookup(local.wireguard_operator_attrs, "namespace", "")
  wireguard_release        = lookup(local.wireguard_operator_attrs, "release_id", "")

  # Convert taints from {key, value, effect} to tolerations format
  tolerations = [
    for taint in local.node_pool_taints : {
      key      = taint.key
      operator = "Equal"
      value    = taint.value
      effect   = taint.effect
    }
  ]

  # Cloud-specific service annotations
  cloud_service_annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
    "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
    "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
    "service.beta.kubernetes.io/azure-load-balancer-internal"      = "false"
  }
}

# Deploy Wireguard CRD using any-k8s-resource utility module
module "wireguard_vpn" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  name      = var.instance_name
  namespace = local.namespace
  advanced_config = {
    annotations = {
      # Create dependency on wireguard operator
      "kubernetes.io/wireguard-operator-release" = local.wireguard_release
    }
  }

  data = {
    apiVersion = "vpn.wireguard-operator.io/v1alpha1"
    kind       = "Wireguard"
    metadata = {
      labels = var.environment.cloud_tags
      annotations = {
        "kubernetes.io/wireguard-operator-release" = local.wireguard_release
      }
    }
    spec = {
      enableIpForwardOnPodInit = local.enable_ip_forward
      serviceType              = local.service_type
      mtu                      = local.mtu
      serviceAnnotations       = local.cloud_service_annotations
      deploymentNodeSelector   = local.node_selector
      deploymentTolerations    = local.tolerations
    }
  }
}
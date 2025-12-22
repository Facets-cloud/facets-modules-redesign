locals {
  spec                = lookup(var.instance, "spec", {})
  namespace           = lookup(local.spec, "namespace", "") != "" ? lookup(local.spec, "namespace", "") : var.environment.namespace
  enable_ip_forward   = lookup(local.spec, "enable_ip_forward", true)
  mtu                 = lookup(local.spec, "mtu", "1500")
  service_annotations = lookup(local.spec, "service_annotations", {})

  # Get node pool details from input
  node_pool_input  = lookup(var.inputs, "node_pool", {})
  node_pool_attrs  = lookup(local.node_pool_input, "attributes", {})
  node_selector    = lookup(local.node_pool_attrs, "node_selector", {})
  node_pool_taints = lookup(local.node_pool_attrs, "taints", [])

  # Get wireguard base chart details for reference
  wireguard_input   = lookup(var.inputs, "wireguard", {})
  wireguard_attrs   = lookup(local.wireguard_input, "attributes", {})
  wireguard_version = lookup(local.wireguard_attrs, "version", "0.31.0")

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

  # Merge user-provided annotations with cloud-specific annotations
  final_service_annotations = merge(local.cloud_service_annotations, local.service_annotations)
}

resource "helm_release" "wireguard_vpn" {
  name             = var.instance_name
  repository       = "https://bryopsida.github.io/wireguard-chart"
  chart            = "wireguard"
  version          = local.wireguard_version
  namespace        = local.namespace
  create_namespace = false
  wait             = true
  atomic           = true
  timeout          = 600

  values = [
    yamlencode({
      # Apply node selector and tolerations from node pool
      nodeSelector = local.node_selector
      tolerations  = local.tolerations

      # Service configuration with annotations
      service = {
        type        = "LoadBalancer"
        annotations = local.final_service_annotations
      }

      # Wireguard specific configuration
      config = {
        mtu = local.mtu
      }

      # Init container for IP forwarding
      initContainers = local.enable_ip_forward ? [
        {
          name    = "enable-ip-forward"
          image   = "busybox:latest"
          command = ["/bin/sh", "-c"]
          args = [
            "sysctl -w net.ipv4.ip_forward=1 && sysctl -w net.ipv4.conf.all.forwarding=1"
          ]
          securityContext = {
            privileged = true
          }
        }
      ] : []

      # Add environment tags as labels
      podLabels = var.environment.cloud_tags
    })
  ]
}

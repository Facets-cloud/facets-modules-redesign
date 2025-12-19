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

  # Build the Wireguard CRD spec
  wireguard_spec = merge(
    {
      enableIpForwardOnPodInit = local.enable_ip_forward
      deploymentTolerations    = local.tolerations
      deploymentNodeSelector   = local.node_selector
      mtu                      = local.mtu
    },
    length(local.final_service_annotations) > 0 ? {
      serviceAnnotations = local.final_service_annotations
    } : {}
  )
}

module "wireguard_vpn_resource" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  instance_name = var.instance_name
  environment   = var.environment

  instance = {
    spec = {
      namespace = local.namespace
      data = {
        apiVersion = "vpn.wireguard-operator.io/v1alpha1"
        kind       = "Wireguard"
        metadata = {
          name      = var.instance_name
          namespace = local.namespace
          labels    = var.environment.cloud_tags
        }
        spec = local.wireguard_spec
      }
    }
  }
}

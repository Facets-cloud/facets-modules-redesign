# Define your terraform resources here

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = local.cert_mgr_namespace
  }
}

resource "helm_release" "cert_manager" {
  depends_on       = [kubernetes_namespace.namespace]
  name             = "cert-manager"
  chart            = "${path.module}/cert-manager-v1.17.1.tgz"
  namespace        = local.cert_mgr_namespace
  create_namespace = false
  cleanup_on_fail  = lookup(local.cert_manager, "cleanup_on_fail", true)
  wait             = lookup(local.cert_manager, "wait", true)
  atomic           = lookup(local.cert_manager, "atomic", false)
  timeout          = lookup(local.cert_manager, "timeout", 600)
  recreate_pods    = lookup(local.cert_manager, "recreate_pods", false)

  values = [
    <<EOF
prometheus_id: ${try(var.inputs.prometheus_details.attributes.helm_release_id, "")}
EOF
    , yamlencode({
      installCRDs  = true
      nodeSelector = local.nodeSelector
      tolerations  = local.tolerations
      replicaCount = 2

      # Enable Gateway API support via config
      config = {
        enableGatewayAPI = local.enable_gateway_api
      }

      webhook = {
        nodeSelector = local.nodeSelector
        tolerations  = local.tolerations
        replicaCount = 3
      }
      cainjector = {
        nodeSelector = local.nodeSelector
        tolerations  = local.tolerations
      }
      startupapicheck = {
        nodeSelector = local.nodeSelector
        tolerations  = local.tolerations
      }
      prometheus = {
        enabled = local.prometheus_enabled
        servicemonitor = {
          enabled = local.prometheus_enabled
        }
      }
      },
      # Add featureGates for Gateway API support when enabled
      local.enable_gateway_api ? {
        featureGates = "ExperimentalGatewayAPISupport=true"
      } : {}
    ),
    yamlencode(local.user_supplied_helm_values),
  ]

}

module "cluster-issuer" {
  depends_on = [helm_release.cert_manager]
  for_each   = local.environments

  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = each.value.name
  namespace       = local.cert_mgr_namespace
  advanced_config = {}

  data = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = each.value.name
    }
    spec = {
      acme = {
        email  = local.acme_email
        server = each.value.url
        privateKeySecretRef = {
          name = "letsencrypt-${each.key}-account-key"
        }
        solvers = each.value.solvers
      }
    }
  }

}

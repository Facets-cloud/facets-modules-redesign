# Define your terraform resources here

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = local.cert_mgr_namespace
  }
}

resource "helm_release" "cert_manager" {
  depends_on = [kubernetes_namespace.namespace]
  name       = "cert-manager"
  # repository       = "https://charts.jetstack.io"
  chart            = "${path.module}/cert-manager-v1.17.1.tgz"
  namespace        = local.cert_mgr_namespace
  create_namespace = false
  # version          = lookup(local.cert_manager, "version", "1.13.3")
  cleanup_on_fail = lookup(local.cert_manager, "cleanup_on_fail", true)
  wait            = lookup(local.cert_manager, "wait", true)
  atomic          = lookup(local.cert_manager, "atomic", false)
  timeout         = lookup(local.cert_manager, "timeout", 600)
  recreate_pods   = lookup(local.cert_manager, "recreate_pods", false)

  values = [
    <<EOF
prometheus_id: ${try(var.inputs.prometheus_details.attributes.helm_release_id, "")}
EOF
    , yamlencode({
      installCRDs  = true
      nodeSelector = local.nodeSelector
      tolerations  = local.tolerations
      replicaCount = 2

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
        enabled = true
        servicemonitor = {
          enabled = true
        }
      }
    }),
    yamlencode(local.user_supplied_helm_values),
  ]

}

module "cluster-issuer" {
  depends_on = [helm_release.cert_manager]
  for_each   = [{}, local.environments][local.use_gts ? 0 : 1]

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


resource "kubernetes_secret" "google-trust-services-prod-account-key" {
  count      = local.use_gts ? 1 : 0
  depends_on = [kubernetes_namespace.namespace]
  metadata {
    name      = "google-trust-services-prod-account-key"
    namespace = local.cert_mgr_namespace
  }
  data = {
    "tls.key" = local.gts_private_key
  }
}

module "cluster-issuer-gts-prod-http01" {
  count           = local.use_gts ? 1 : 0
  depends_on      = [helm_release.cert_manager]
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "gts-production-http01"
  namespace       = local.cert_mgr_namespace
  advanced_config = {}

  data = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "gts-production-http01"
    }
    spec = {
      acme = {
        email                       = local.acme_email
        server                      = local.use_gts ? "https://dv.acme-v02.api.pki.goog/directory" : "https://acme-v02.api.letsencrypt.org/directory"
        disableAccountKeyGeneration = true
        privateKeySecretRef = {
          name = kubernetes_secret.google-trust-services-prod-account-key[0].metadata[0].name
        }
        solvers = [
          {
            http01 = {
              ingress = {
                podTemplate = {
                  spec = {
                    nodeSelector = local.nodeSelector
                    tolerations  = local.tolerations
                  }
                }
              }
            }
          },
        ]
      }
    }
  }

}

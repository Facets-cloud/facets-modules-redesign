# RBAC for the CRD installer job
resource "kubernetes_service_account" "crd_installer" {
  metadata {
    name      = "kb-crd-installer"
    namespace = "default"
  }
}

resource "kubernetes_cluster_role" "crd_installer" {
  metadata {
    name = "kb-crd-installer"
  }

  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
    verbs      = ["get", "list", "create", "update", "patch"]
  }
}

resource "kubernetes_cluster_role_binding" "crd_installer" {
  metadata {
    name = "kb-crd-installer"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.crd_installer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.crd_installer.metadata[0].name
    namespace = "default"
  }
}

# CRD installer job
# Downloads kubeblocks_crds.yaml from GitHub and applies via kubectl.
# Terraform tracks only this Job — the CRDs themselves are NOT in state.
resource "kubernetes_job" "install_crds" {
  metadata {
    generate_name = "kb-crd-install-"
    namespace     = "default"
  }

  spec {
    backoff_limit = 3

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"       = "kb-crd-installer"
          "app.kubernetes.io/managed-by" = "terraform"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.crd_installer.metadata[0].name
        restart_policy       = "Never"

        init_container {
          name    = "download-crds"
          image   = "alpine:3.19"
          command = ["wget", "-qO", "/crds/kubeblocks_crds.yaml", "https://github.com/apecloud/kubeblocks/releases/download/v${var.instance.spec.version}/kubeblocks_crds.yaml"]

          volume_mount {
            name       = "crds-volume"
            mount_path = "/crds"
          }
        }

        container {
          name    = "apply-crds"
          image   = "bitnamilegacy/kubectl:1.33.4"
          command = ["kubectl", "apply", "--server-side", "--force-conflicts", "-f", "/crds/kubeblocks_crds.yaml"]

          volume_mount {
            name       = "crds-volume"
            mount_path = "/crds"
          }
        }

        volume {
          name = "crds-volume"
          empty_dir {}
        }
      }
    }
  }

  wait_for_completion = true

  timeouts {
    create = "15m"
  }
}

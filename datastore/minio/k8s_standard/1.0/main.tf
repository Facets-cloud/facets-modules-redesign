# MinIO Object Storage Module - KubeBlocks v1.0
# Creates and manages MinIO object storage clusters using KubeBlocks operator
# REQUIRES: KubeBlocks operator must be deployed first (CRDs must exist)

# Kubernetes Namespace for MinIO Cluster
resource "kubernetes_namespace" "minio_cluster" {
  count = local.namespace == var.environment.namespace ? 0 : 1
  metadata {
    name = local.namespace

    annotations = {
      "kubeblocks.io/operator-release-id"    = var.inputs.kubeblocks_operator.interfaces.output.release_id
      "kubeblocks.io/operator-dependency-id" = var.inputs.kubeblocks_operator.interfaces.output.dependency_id
    }

    labels = merge(
      {
        "app.kubernetes.io/name"       = "minio-cluster"
        "app.kubernetes.io/instance"   = var.instance_name
        "app.kubernetes.io/managed-by" = "terraform"
      },
      var.environment.cloud_tags
    )
  }

  timeouts {
    delete = "5m"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
      metadata[0].annotations
    ]
  }
}

# MinIO Cluster
# Using any-k8s-resource module to avoid plan-time CRD validation
module "minio_cluster" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  name         = local.cluster_name
  namespace    = local.namespace
  release_name = "minio-${local.cluster_name}-${substr(var.inputs.kubeblocks_operator.interfaces.output.release_id, 0, 8)}"

  depends_on = [
    kubernetes_namespace.minio_cluster
  ]

  data = {
    apiVersion = "apps.kubeblocks.io/v1"
    kind       = "Cluster"

    metadata = {
      name      = local.cluster_name
      namespace = local.namespace

      annotations = {
        "kubeblocks.io/operator-release-id"    = var.inputs.kubeblocks_operator.interfaces.output.release_id
        "kubeblocks.io/operator-dependency-id" = var.inputs.kubeblocks_operator.interfaces.output.dependency_id
      }

      labels = merge(
        {
          "app.kubernetes.io/name"       = "minio"
          "app.kubernetes.io/instance"   = var.instance_name
          "app.kubernetes.io/managed-by" = "terraform"
          "app.kubernetes.io/version"    = var.instance.spec.minio_version
        },
        var.environment.cloud_tags
      )
    }

    spec = {
      clusterDef        = "minio"
      terminationPolicy = var.instance.spec.termination_policy

      componentSpecs = [
        merge(
          {
            name         = "minio"
            componentDef = "minio-${local.release_version}"
            replicas     = local.replicas

            # Environment variables for MinIO configuration
            env = concat(
              local.buckets_to_create != "" ? [
                {
                  name  = "MINIO_BUCKETS"
                  value = local.buckets_to_create
                }
              ] : [],
              [
                {
                  name  = "MINIO_VOLUMES_PER_SERVER"
                  value = tostring(var.instance.spec.volumes_per_server)
                }
              ]
            )

            resources = {
              limits = {
                cpu    = var.instance.spec.resources.cpu_limit
                memory = var.instance.spec.resources.memory_limit
              }
              requests = {
                cpu    = var.instance.spec.resources.cpu_request
                memory = var.instance.spec.resources.memory_request
              }
            }

            volumeClaimTemplates = [
              for i in range(var.instance.spec.volumes_per_server) : {
                name = "data-${i}"
                spec = merge(
                  {
                    accessModes = ["ReadWriteOnce"]
                    resources = {
                      requests = {
                        storage = var.instance.spec.storage.size
                      }
                    }
                  },
                  var.instance.spec.storage.storage_class != "" ? {
                    storageClassName = var.instance.spec.storage.storage_class
                  } : {}
                )
              }
            ]
          },

          # schedulingPolicy (nodeSelector, affinity, tolerations)
          {
            schedulingPolicy = merge(
              # Pod anti-affinity for HA
              local.enable_pod_anti_affinity ? {
                affinity = {
                  podAntiAffinity = {
                    preferredDuringSchedulingIgnoredDuringExecution = [
                      {
                        weight = 100
                        podAffinityTerm = {
                          labelSelector = {
                            matchLabels = {
                              "app.kubernetes.io/instance"        = local.cluster_name
                              "app.kubernetes.io/managed-by"      = "kubeblocks"
                              "apps.kubeblocks.io/component-name" = "minio"
                            }
                          }
                          topologyKey = "kubernetes.io/hostname"
                        }
                      }
                    ]
                  }
                }
              } : {},

              # Node selector (if provided)
              length(local.node_selector) > 0 ? {
                nodeSelector = local.node_selector
              } : {},

              # Tolerations
              {
                tolerations = length(local.tolerations) > 0 ? local.tolerations : [
                  {
                    key      = "CriticalAddonsOnly"
                    operator = "Exists"
                    effect   = "NoSchedule"
                  }
                ]
              }
            )
          }
        )
      ]
    }
  }

  advanced_config = {
    wait            = true
    timeout         = 1800 # 30 minutes
    cleanup_on_fail = true
    max_history     = 3
  }
}

# Wait for KubeBlocks to create and populate the connection secret
resource "time_sleep" "wait_for_credentials" {
  depends_on = [module.minio_cluster]

  create_duration = "60s"
  triggers = {
    cluster_name = local.cluster_name
    namespace    = local.namespace
  }
}

# Data Source: Connection Credentials Secret
# Discover all account secrets
data "kubernetes_resources" "minio_secrets" {
  api_version    = "v1"
  kind           = "Secret"
  namespace      = local.namespace
  label_selector = "app.kubernetes.io/instance=${local.cluster_name},apps.kubeblocks.io/system-account=root"

  depends_on = [time_sleep.wait_for_credentials]
}

# Fetch the root account secret
data "kubernetes_secret" "minio_credentials" {
  metadata {
    name      = try(data.kubernetes_resources.minio_secrets.objects[0].metadata.name, "${local.cluster_name}-minio-account-root")
    namespace = local.namespace
  }

  depends_on = [data.kubernetes_resources.minio_secrets]
}

# Data Source: MinIO API Service
# KubeBlocks auto-creates this service with format: {cluster-name}-minio
data "kubernetes_service" "minio_api" {
  metadata {
    name      = "${local.cluster_name}-minio"
    namespace = local.namespace
  }

  depends_on = [module.minio_cluster]
}

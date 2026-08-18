# Cassandra Cluster Module - k8ssandra-operator
# Creates and manages Apache Cassandra clusters via the K8ssandraCluster CR
# REQUIRES: k8ssandra-operator must be deployed first (CRDs must exist,
# operator must be cluster-scoped — the k8ssandra-operator/helm module is)

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  resource_name = var.instance_name
  resource_type = "cassandra"
  environment   = var.environment
  limit         = 40
  is_k8s        = true
}

# Cassandra cluster via K8ssandraCluster CR
# Using any-k8s-resource module to avoid plan-time CRD validation
module "cassandra_cluster" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  name         = local.cluster_name
  namespace    = local.namespace
  release_name = "cassandra-${local.cluster_name}-${substr(var.inputs.k8ssandra_operator.attributes.release_id, 0, 8)}"

  data = {
    apiVersion = "k8ssandra.io/v1alpha1"
    kind       = "K8ssandraCluster"

    metadata = {
      name      = local.cluster_name
      namespace = local.namespace

      annotations = {
        "k8ssandra.io/operator-release-id" = var.inputs.k8ssandra_operator.attributes.release_id
      }

      labels = merge(
        {
          "app.kubernetes.io/name"       = "cassandra"
          "app.kubernetes.io/instance"   = var.instance_name
          "app.kubernetes.io/managed-by" = "terraform"
          "app.kubernetes.io/version"    = var.instance.spec.cassandra_version
        },
        var.environment.cloud_tags
      )
    }

    spec = {
      cassandra = merge(
        {
          serverVersion = var.instance.spec.cassandra_version

          # Soft anti-affinity lets multiple Cassandra pods share a worker when
          # capacity requires it; hard anti-affinity would strand pods Pending
          # on small node pools.
          softPodAntiAffinity = local.soft_pod_anti_affinity

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

          storageConfig = {
            cassandraDataVolumeClaimSpec = merge(
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

          datacenters = [
            merge(
              {
                metadata = {
                  name = local.datacenter
                }
                size = local.replicas
              },
              # DatacenterOptions has no nodeSelector; racks carry node affinity
              length(local.node_selector) > 0 ? {
                racks = [
                  {
                    name               = "default"
                    nodeAffinityLabels = local.node_selector
                  }
                ]
              } : {}
            )
          ]
        },
        length(local.tolerations) > 0 ? {
          tolerations = local.tolerations
        } : {}
      )
    }
  }

  advanced_config = {
    wait            = true
    timeout         = 2700 # 45 minutes — ring bootstrap is slow
    cleanup_on_fail = true
    max_history     = 3
  }
}

# Wait for the operator to generate the superuser secret
# (created early in reconciliation, before the ring is Ready)
resource "time_sleep" "wait_for_credentials" {
  depends_on = [module.cassandra_cluster]

  create_duration = "120s"
  triggers = {
    cluster_name = local.cluster_name
    namespace    = local.namespace
  }
}

# Superuser credentials secret: "<cluster_name>-superuser" (keys: username, password)
data "kubernetes_secret" "superuser" {
  metadata {
    name      = local.superuser_secret_name
    namespace = local.namespace
  }

  depends_on = [time_sleep.wait_for_credentials]
}

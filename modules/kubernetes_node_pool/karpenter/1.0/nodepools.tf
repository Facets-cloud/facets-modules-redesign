# Create EC2NodeClass for this instance using any-k8s-resource module
module "ec2_node_class" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  name         = "${var.instance_name}-nodeclass"
  namespace    = local.karpenter_namespace
  release_name = "${var.instance_name}-ec2nodeclass"

  data = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"

    metadata = {
      name      = "${var.instance_name}-nodeclass"
      namespace = local.karpenter_namespace
      annotations = {
        # Reference helm_release_id to create dependency on Karpenter installation
        "facets.cloud/karpenter-release-id" = var.inputs.karpenter_details.attributes.helm_release_id
      }
    }

    spec = {
      # Use the instance profile from karpenter_details input
      instanceProfile = local.node_instance_profile_name

      # Specify AMI family so Karpenter can generate correct UserData
      # EKS 1.33 requires AL2023
      amiFamily = "AL2023"

      amiSelectorTerms = [
        {
          # Use Amazon Linux 2023 EKS optimized AMI
          alias = "al2023@latest"
        }
      ]

      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.cluster_name
          }
        }
      ]

      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.cluster_name
          }
        }
      ]
    }
  }

  advanced_config = {
    wait            = true
    timeout         = 300
    cleanup_on_fail = true
    max_history     = 10
  }
}

# Create NodePool for this instance using any-k8s-resource module
module "node_pool" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  name         = "${var.instance_name}-nodepool"
  namespace    = local.karpenter_namespace
  release_name = "${var.instance_name}-nodepool"

  data = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"

    metadata = {
      name      = "${var.instance_name}-nodepool"
      namespace = local.karpenter_namespace
    }

    spec = {
      template = {
        metadata = {
          labels = merge(
            lookup(var.instance.spec, "labels", {}),
            {
              # Reference helm_release_id to create dependency on Karpenter installation
              "facets.cloud/karpenter-release-id" = var.inputs.karpenter_details.attributes.helm_release_id
            }
          )
        }

        spec = merge(
          {
            requirements = concat(
              [
                {
                  key      = "kubernetes.io/arch"
                  operator = "In"
                  values   = lookup(var.instance.spec, "architecture", ["amd64"])
                },
                {
                  key      = "kubernetes.io/os"
                  operator = "In"
                  values   = ["linux"]
                },
                {
                  key      = "karpenter.sh/capacity-type"
                  operator = "In"
                  values   = lookup(var.instance.spec, "capacity_types", ["on-demand", "spot"])
                },
                # Generate list of instance types from families and sizes
                {
                  key      = "node.kubernetes.io/instance-type"
                  operator = "In"
                  values = flatten([
                    for family in lookup(var.instance.spec, "instance_families", ["t3", "t3a"]) : [
                      for size in lookup(var.instance.spec, "instance_sizes", ["medium", "large", "xlarge"]) :
                      "${family}.${size}"
                    ]
                  ])
                }
              ],
              []
            )

            nodeClassRef = {
              group = "karpenter.k8s.aws"
              kind  = "EC2NodeClass"
              name  = "${var.instance_name}-nodeclass"
            }

            expireAfter = "720h"
          },
          # Add taints if configured
          length(lookup(var.instance.spec, "taints", {})) > 0 ? {
            taints = [
              for taint_key, taint_config in lookup(var.instance.spec, "taints", {}) : {
                key    = taint_key
                value  = taint_config.value
                effect = taint_config.effect
              }
            ]
          } : {}
        )
      }

      limits = {
        cpu    = lookup(var.instance.spec, "cpu_limits", "1000")
        memory = lookup(var.instance.spec, "memory_limits", "1000Gi")
      }

      disruption = {
        consolidationPolicy = lookup(var.instance.spec, "enable_consolidation", true) ? "WhenEmptyOrUnderutilized" : "WhenEmpty"
        consolidateAfter    = "1m"
      }
    }
  }

  advanced_config = {
    wait            = true
    timeout         = 300
    cleanup_on_fail = true
    max_history     = 10
  }

  # Ensure EC2NodeClass is created before NodePool
  depends_on = [
    module.ec2_node_class
  ]
}

# Create EC2NodeClass for this instance
resource "kubernetes_manifest" "ec2_node_class" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "${var.instance_name}-nodeclass"
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

  # Ignore fields that Karpenter controller manages
  computed_fields = [
    "metadata.finalizers",
    "metadata.annotations",
    "status"
  ]

  # Allow Terraform to override field manager conflicts with Karpenter controller
  field_manager {
    force_conflicts = true
  }
}

# Create NodePool for this instance
resource "kubernetes_manifest" "node_pool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "${var.instance_name}-nodepool"
    }
    spec = {
      template = {
        metadata = {
          labels = lookup(var.instance.spec, "labels", {})
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

  # Ignore fields that Karpenter controller manages
  computed_fields = [
    "metadata.finalizers",
    "metadata.annotations",
    "metadata.labels",
    "status"
  ]

  # Allow Terraform to override field manager conflicts with Karpenter controller
  field_manager {
    force_conflicts = true
  }

  depends_on = [
    kubernetes_manifest.ec2_node_class
  ]
}

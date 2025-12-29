# Create EC2NodeClass for each configured pool
resource "kubernetes_manifest" "ec2_node_class" {
  for_each = var.instance.spec.node_pools

  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "${each.key}-${var.instance_name}"
    }
    spec = {
      # Use the instance profile we create in main.tf instead of letting Karpenter create one
      instanceProfile = aws_iam_instance_profile.karpenter_node.name

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

  depends_on = [
    helm_release.karpenter,
    aws_ec2_tag.karpenter_subnet_discovery,
    aws_ec2_tag.karpenter_sg_discovery
  ]
}

# Create NodePool for each configured pool
resource "kubernetes_manifest" "node_pool" {
  for_each = var.instance.spec.node_pools

  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "${each.key}-${var.instance_name}"
    }
    spec = {
      template = {
        spec = {
          requirements = concat(
            [
              {
                key      = "kubernetes.io/arch"
                operator = "In"
                values   = lookup(each.value, "architecture", ["amd64"])
              },
              {
                key      = "kubernetes.io/os"
                operator = "In"
                values   = ["linux"]
              },
              {
                key      = "karpenter.sh/capacity-type"
                operator = "In"
                values   = lookup(each.value, "capacity_types", ["on-demand", "spot"])
              },
              # Use node.kubernetes.io/instance-type instead of restricted karpenter.k8s.aws labels
              # Generate list of instance types from families and sizes
              {
                key      = "node.kubernetes.io/instance-type"
                operator = "In"
                values = flatten([
                  for family in lookup(each.value, "instance_families", ["t3", "t3a"]) : [
                    for size in lookup(each.value, "instance_sizes", ["medium", "large", "xlarge"]) :
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
            name  = "${each.key}-${var.instance_name}"
          }
          expireAfter = "720h"
        }
      }
      limits = {
        cpu    = lookup(each.value, "cpu_limits", "1000")
        memory = lookup(each.value, "memory_limits", "1000Gi")
      }
      disruption = {
        consolidationPolicy = var.instance.spec.enable_consolidation ? "WhenEmptyOrUnderutilized" : "WhenEmpty"
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
variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      # Node pool instance configuration
      instance_families = optional(list(string), ["t3", "t3a"])
      instance_sizes    = optional(list(string), ["medium", "large", "xlarge"])
      capacity_types    = optional(list(string), ["on-demand", "spot"])
      architecture      = optional(list(string), ["amd64"])

      # Node pool limits
      cpu_limits    = optional(string, "1000")
      memory_limits = optional(string, "1000Gi")

      # Node pool behavior
      enable_consolidation = optional(bool, true)

      # Node scheduling
      labels = optional(map(string), {})
      taints = optional(map(object({
        value  = string
        effect = string
      })), {})

      # Tags
      tags = optional(map(string), {})
    })
  })
}

variable "instance_name" {
  type        = string
  description = "Unique architectural name from blueprint"
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    namespace   = optional(string)
    cloud_tags  = optional(map(string), {})
  })
  description = "Environment context including name and cloud tags"
}

variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = object({
        aws_region     = string
        aws_account_id = string
        aws_iam_role   = string
        external_id    = optional(string)
        session_name   = optional(string)
      })
    })
    kubernetes_details = object({
      attributes = object({
        cluster_endpoint       = string
        cluster_ca_certificate = string
        cluster_name           = string
        cluster_version        = string
        cluster_arn            = string
        cluster_id             = string
        oidc_issuer_url        = string
        oidc_provider          = string
        oidc_provider_arn      = string
        node_security_group_id = string
        kubernetes_provider_exec = object({
          api_version = string
          command     = string
          args        = list(string)
        })
      })
    })
    network_details = object({
      attributes = object({
        vpc_id              = string
        private_subnet_ids  = list(string)
        public_subnet_ids   = list(string)
        database_subnet_ids = optional(list(string), [])
      })
    })
    # Required input - from karpenter controller module
    karpenter_details = object({
      attributes = object({
        node_instance_profile_name = string
        node_role_arn              = string
        controller_role_arn        = optional(string)
        karpenter_namespace        = optional(string, "kube-system")
        karpenter_service_account  = optional(string, "karpenter")
        helm_release_id            = string
      })
    })
  })
  description = "Inputs from dependent modules"
}

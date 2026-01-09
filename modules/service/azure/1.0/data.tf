# Read control plane metadata from environment variables
# This replaces the deprecated var.cc_metadata, var.cluster, var.baseinfra pattern
data "external" "cc_env" {
  program = ["sh", "-c", <<-EOT
    echo "{\"cc_host\":\"$TF_VAR_cc_host\",\"cc_auth_token\":\"$TF_VAR_cc_auth_token\",\"cc_region\":\"$TF_VAR_cc_region\",\"cc_tenant_provider\":\"$TF_VAR_cc_tenant_provider\",\"tenant_base_domain\":\"$TF_VAR_tenant_base_domain\",\"tenant_base_domain_id\":\"$TF_VAR_tenant_base_domain_id\"}"
  EOT
  ]
}

locals {
  # Control plane metadata constructed from environment variables
  # This object is passed to utility modules that expect cc_metadata
  cc_metadata = {
    cc_host               = data.external.cc_env.result.cc_host
    cc_auth_token         = data.external.cc_env.result.cc_auth_token
    cc_region             = data.external.cc_env.result.cc_region
    cc_tenant_provider    = data.external.cc_env.result.cc_tenant_provider
    tenant_base_domain    = data.external.cc_env.result.tenant_base_domain
    tenant_base_domain_id = data.external.cc_env.result.tenant_base_domain_id
  }

  # Cluster metadata from environment variable
  cluster = {
    id                       = var.environment.cluster_id
    createdBy                = null
    k8sRequestsToLimitsRatio = 1
  }

  # Base infrastructure - empty object as placeholder
  # Utility module may not actually use this
  baseinfra = {}
}

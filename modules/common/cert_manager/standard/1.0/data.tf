# Read control plane metadata from environment variables
# This replaces the deprecated var.cc_metadata and var.cluster pattern
data "external" "cc_env" {
  program = ["sh", "-c", <<-EOT
    echo "{\"cc_tenant_provider\":\"$TF_VAR_cc_tenant_provider\",\"cc_region\":\"$TF_VAR_cc_region\",\"tenant_base_domain\":\"$TF_VAR_tenant_base_domain\"}"
  EOT
  ]
}

locals {
  # Control plane metadata from environment variables
  cc_tenant_provider = data.external.cc_env.result.cc_tenant_provider
  cc_region          = data.external.cc_env.result.cc_region
  tenant_base_domain = data.external.cc_env.result.tenant_base_domain
}

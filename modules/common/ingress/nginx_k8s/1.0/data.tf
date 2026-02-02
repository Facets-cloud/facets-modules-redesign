# Read control plane metadata from environment variables
# This replaces the deprecated var.cc_metadata pattern
data "external" "cc_env" {
  program = ["sh", "-c", <<-EOT
    echo "{\"cc_tenant_provider\":\"$TF_VAR_cc_tenant_provider\",\"tenant_base_domain\":\"$TF_VAR_tenant_base_domain\",\"tenant_base_domain_id\":\"$TF_VAR_tenant_base_domain_id\"}"
  EOT
  ]
}

locals {
  # Control plane metadata from environment variables
  cc_tenant_provider    = data.external.cc_env.result.cc_tenant_provider
  tenant_base_domain    = data.external.cc_env.result.tenant_base_domain
  tenant_base_domain_id = data.external.cc_env.result.tenant_base_domain_id
}

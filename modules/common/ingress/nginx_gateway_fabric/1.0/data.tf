# Read control plane metadata from environment variables
# This replaces the deprecated var.cc_metadata pattern
data "external" "cc_env" {
  program = ["sh", "-c", <<-EOT
    echo "{\"cc_tenant_provider\":\"$TF_VAR_cc_tenant_provider\",\"tenant_base_domain\":\"$TF_VAR_tenant_base_domain\"}"
  EOT
  ]
}

# Fetch Route53 zone by domain name
data "aws_route53_zone" "base-domain-zone" {
  count    = lower(local.cc_tenant_provider != "" ? local.cc_tenant_provider : "aws") == "aws" ? 1 : 0
  name     = local.tenant_base_domain
  provider = "aws3tooling"
}

locals {
  # Control plane metadata from environment variables
  cc_tenant_provider = data.external.cc_env.result.cc_tenant_provider
  tenant_base_domain = data.external.cc_env.result.tenant_base_domain
  # Get zone_id from Route53 data source (queried by domain name)
  tenant_base_domain_id = length(data.aws_route53_zone.base-domain-zone) > 0 ? data.aws_route53_zone.base-domain-zone[0].zone_id : ""
}

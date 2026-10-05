# Read control plane metadata from environment variables
# This replaces the deprecated var.cc_metadata pattern
data "external" "cc_env" {
  program = ["sh", "-c", <<-EOT
    echo "{\"cc_host\":\"$TF_VAR_cc_host\",\"cc_auth_token\":\"$TF_VAR_cc_auth_token\"}"
  EOT
  ]
}

locals {
  # Control plane metadata from environment variables
  cc_host       = data.external.cc_env.result.cc_host
  cc_auth_token = data.external.cc_env.result.cc_auth_token
}

# ╔═══════════════════════════════════════════════════════════╗
# ║ Output contract: @facets/clickhouse-keeper                ║
# ║ Keys managed by CLI — fill in the values only           ║
# ║ Do not add or remove keys. Do not rename.                 ║
# ║                                                           ║
# ║ View schema: raptor get output-type @facets/clickhouse-ke ║
# ╚═══════════════════════════════════════════════════════════╝

locals {
  output_attributes = {
    namespace    = local.namespace
    port         = 2181
    replicas     = local.replicas
    service_host = "keeper-${local.keeper_name}.${local.namespace}.svc.${local.cluster_domain}"
  }
  output_interfaces = {
  }
}

# --- END MANAGED SECTION --- Add your custom outputs below ---

# Add your custom Terraform outputs below this line.

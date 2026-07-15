# ╔═══════════════════════════════════════════════════════════╗
# ║ Output contract: @facets/clickhouse                       ║
# ║ Keys managed by CLI — fill in the values only           ║
# ║ Do not add or remove keys. Do not rename.                 ║
# ║                                                           ║
# ║ View schema: raptor get output-type @facets/clickhouse    ║
# ╚═══════════════════════════════════════════════════════════╝

locals {
  output_attributes = {
    cluster_name = local.cluster_name
    http_port    = 8123
    namespace    = local.namespace
    service_host = "clickhouse-${local.cluster_name}.${local.namespace}.svc.cluster.local"
    tcp_port     = 9000
  }
  output_interfaces = {
  }
}

# --- END MANAGED SECTION --- Add your custom outputs below ---

# Add your custom Terraform outputs below this line.

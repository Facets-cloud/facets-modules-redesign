# ╔═══════════════════════════════════════════════════════════╗
# ║ Output contract: @facets/clickhouse-operator              ║
# ║ Keys managed by CLI — fill in the values only           ║
# ║ Do not add or remove keys. Do not rename.                 ║
# ║                                                           ║
# ║ View schema: raptor get output-type @facets/clickhouse-op ║
# ╚═══════════════════════════════════════════════════════════╝

locals {
  output_attributes = {
    namespace    = helm_release.operator.namespace
    release_name = helm_release.operator.name
  }
  output_interfaces = {
  }
}

# --- END MANAGED SECTION --- Add your custom outputs below ---

# Add your custom Terraform outputs below this line.

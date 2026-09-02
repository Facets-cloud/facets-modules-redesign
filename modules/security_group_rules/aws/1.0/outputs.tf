# ╔═══════════════════════════════════════════════════════════╗
# ║ Output contract: @facets/security_group_rules             ║
# ║ Keys managed by CLI — fill in the values only           ║
# ║ Do not add or remove keys. Do not rename.                 ║
# ║                                                           ║
# ║ View schema: raptor get output-type @facets/security_grou ║
# ╚═══════════════════════════════════════════════════════════╝

locals {
  output_attributes = {
    rule_ids = { for name, rule in aws_vpc_security_group_ingress_rule.this : name => rule.id }
  }
  output_interfaces = {
  }
}

# --- END MANAGED SECTION --- Add your custom outputs below ---

# Add your custom Terraform outputs below this line.

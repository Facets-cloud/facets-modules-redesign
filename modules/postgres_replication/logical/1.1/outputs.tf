# ╔═══════════════════════════════════════════════════════════╗
# ║ Output contract: @facets/k8s_resource                     ║
# ║ Keys managed by CLI — fill in the values only           ║
# ║ Do not add or remove keys. Do not rename.                 ║
# ║                                                           ║
# ║ View schema: raptor get output-type @facets/k8s_resource  ║
# ╚═══════════════════════════════════════════════════════════╝

locals {
  output_attributes = {
    resource_name      = local.safe_name
    resource_namespace = local.namespace
  }
  output_interfaces = {
  }
}

# --- END MANAGED SECTION --- Add your custom outputs below ---

# Add your custom Terraform outputs below this line.

output "target_login_role_passwords" {
  value = {
    for role, password in random_password.target_login_roles :
    role => password.result
  }
  sensitive = true
}

# Output attributes and interfaces

locals {
  # First host for primary URLs (usually the bare domain)
  primary_host = length(local.unique_hosts) > 0 ? local.unique_hosts[0] : ""

  output_attributes = {
    lb_name       = local.name
    lb_ip_address = local.lb_ip_address
  }

  # Output interfaces per rule (matching nginx ingress pattern)
  # Each rule_key maps to an interface with host, port, connection_string
  output_interfaces = {
    for rule_key, rule in local.rules_by_host : rule_key => {
      connection_string = "https://${rule.host}"
      host              = rule.host
      port              = 443
    }
  }
}

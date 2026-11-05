locals {
  username        = lookup(var.instance.spec, "basic_auth", false) ? "${var.instance_name}user" : ""
  password        = lookup(var.instance.spec, "basic_auth", false) && length(random_string.basic_auth_password) > 0 ? random_string.basic_auth_password[0].result : ""
  is_auth_enabled = length(local.username) > 0 && length(local.password) > 0

  output_attributes = merge(
    {
      # Always include base_domain for backward compatibility
      base_domain   = local.base_domain
      gateway_class = local.gateway_class_name
      gateway_name  = local.name
      # Load balancer DNS information
      loadbalancer_dns = try(data.kubernetes_service.gateway_lb.status.0.load_balancer.0.ingress.0.hostname,
        data.kubernetes_service.gateway_lb.status.0.load_balancer.0.ingress.0.ip,
      null)
      loadbalancer_hostname = try(data.kubernetes_service.gateway_lb.status.0.load_balancer.0.ingress.0.hostname, null)
      loadbalancer_ip       = try(data.kubernetes_service.gateway_lb.status.0.load_balancer.0.ingress.0.ip, null)
    },
    # Only include base_domain_enabled if base domain is not disabled
    !lookup(var.instance.spec, "disable_base_domain", false) ? {
      base_domain_enabled = true
      } : {
      base_domain_enabled = false
    }
  )

  # Generate output interfaces for every rule × domain combination
  # Each rule is expanded across all configured domains (not just the base domain)
  # Base domain entries are excluded when disable_base_domain is true
  output_interfaces = length(local.rulesFiltered) == 0 || length(local.domains) == 0 ? {} : merge([
    for route_key, route in local.rulesFiltered : {
      for domain_key, domain in local.domains :
      "${route_key}--${domain_key}" => {
        connection_string = local.is_auth_enabled ? "https://${local.username}:${local.password}@${
          lookup(route, "domain_prefix", null) == null || lookup(route, "domain_prefix", null) == "" ?
          domain.domain :
          "${lookup(route, "domain_prefix", null)}.${domain.domain}"
          }" : "https://${
          lookup(route, "domain_prefix", null) == null || lookup(route, "domain_prefix", null) == "" ?
          domain.domain :
          "${lookup(route, "domain_prefix", null)}.${domain.domain}"
        }"
        host = (
          lookup(route, "domain_prefix", null) == null || lookup(route, "domain_prefix", null) == "" ?
          domain.domain :
          "${lookup(route, "domain_prefix", null)}.${domain.domain}"
        )
        port     = 443
        username = local.username
        password = local.password
        secrets  = local.is_auth_enabled ? ["connection_string", "password"] : []
      }
    }
  ]...)
}

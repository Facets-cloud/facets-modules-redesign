locals {
  # Extract load balancer details
  load_balancer_hostname = (
    lookup(var.instance.spec, "service_type", "LoadBalancer") == "LoadBalancer" &&
    length(data.kubernetes_service.traefik.status) > 0 &&
    length(data.kubernetes_service.traefik.status[0].load_balancer) > 0 &&
    length(data.kubernetes_service.traefik.status[0].load_balancer[0].ingress) > 0
  ) ? lookup(data.kubernetes_service.traefik.status[0].load_balancer[0].ingress[0], "hostname", "") : ""

  load_balancer_ip = (
    lookup(var.instance.spec, "service_type", "LoadBalancer") == "LoadBalancer" &&
    length(data.kubernetes_service.traefik.status) > 0 &&
    length(data.kubernetes_service.traefik.status[0].load_balancer) > 0 &&
    length(data.kubernetes_service.traefik.status[0].load_balancer[0].ingress) > 0
  ) ? lookup(data.kubernetes_service.traefik.status[0].load_balancer[0].ingress[0], "ip", "") : ""

  # Determine endpoint host
  endpoint_host = local.load_balancer_hostname != "" ? local.load_balancer_hostname : (
    local.load_balancer_ip != "" ? local.load_balancer_ip : "cluster-internal"
  )

  # Build list of configured domains
  configured_domains = [
    for domain_key, domain_config in lookup(var.instance.spec, "domains", {}) :
    lookup(domain_config, "domain", "")
  ]

  # Build list of configured routes
  configured_routes = [
    for rule_key, rule in lookup(var.instance.spec, "rules", {}) :
    {
      name          = rule_key
      domain_prefix = lookup(rule, "domain_prefix", "*")
      path          = lookup(rule, "path", "/")
      service_name  = lookup(rule, "service_name", "")
      disabled      = lookup(rule, "disable", false)
    }
  ]

  output_attributes = {
    ingress_class_name     = "traefik"
    namespace              = local.namespace
    service_name           = local.name
    service_type           = lookup(var.instance.spec, "service_type", "LoadBalancer")
    load_balancer_hostname = local.load_balancer_hostname
    load_balancer_ip       = local.load_balancer_ip
    helm_release_name      = helm_release.traefik.name
    helm_release_version   = helm_release.traefik.version
    configured_domains     = local.configured_domains
    total_rules            = length(local.configured_routes)
    active_rules           = length([for r in local.configured_routes : r if !r.disabled])
    ssl_redirect_enabled   = lookup(local.spec, "force_ssl_redirection", true)
    basic_auth_enabled     = lookup(local.spec, "basic_auth", false)
    grpc_enabled           = lookup(local.spec, "grpc", false)
    base_domain            = local.has_tenant_base_domain ? local.base_domain : ""
    base_domain_tls_secret = local.has_tenant_base_domain && lookup(lookup(local.spec, "certificate", {}), "use_cert_manager", false) ? "${local.name}-base-domain-tls" : ""
  }

  output_interfaces = {
    http = {
      host     = local.endpoint_host
      port     = "80"
      protocol = "http"
    }
    https = {
      host     = local.endpoint_host
      port     = "443"
      protocol = "https"
    }
  }
}

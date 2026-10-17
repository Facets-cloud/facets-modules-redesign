output "output_attributes" {
  value       = local.output_attributes
  description = "Module output attributes"
}

output "output_interfaces" {
  value       = local.output_interfaces
  sensitive   = true
  description = "Module output interfaces (rule × domain cross-product)"
}

output "domains" {
  value = concat(
    # Only include base domain if not disabled
    !lookup(var.instance.spec, "disable_base_domain", false) ? [local.base_domain] : [],
    [for d in values(lookup(var.instance.spec, "domains", {})) : d.domain if can(d.domain)]
  )
}

output "nginx_gateway_fabric" {
  value = {
    resource_type = "ingress"
    resource_name = var.instance_name
  }
}

output "domain" {
  value = !lookup(var.instance.spec, "disable_base_domain", false) ? local.base_domain : null
}

output "secure_endpoint" {
  value = !lookup(var.instance.spec, "disable_base_domain", false) ? "https://${local.base_domain}" : null
}

output "gateway_class" {
  value       = local.gateway_class_name
  description = "The GatewayClass name used by this gateway"
}

output "gateway_name" {
  value       = local.name
  description = "The Gateway resource name"
}

output "subdomain" {
  value = !lookup(var.instance.spec, "disable_base_domain", false) ? {
    (var.instance_name) = merge(
      {
        for s in try(var.instance.spec.subdomains, []) :
        "${s}.domain" => "${s}.${local.base_domain}"
      },
      {
        for s in try(var.instance.spec.subdomains, []) :
        "${s}.secure_endpoint" => "https://${s}.${local.base_domain}"
      }
    )
  } : {}
}

output "tls_secret" {
  value = {
    for domain_key, domain in local.domains :
    domain_key => lookup(domain, "certificate_reference", "") != "" ? domain.certificate_reference : "${local.name}-${domain_key}-tls-cert"
  }
  description = "Map of domain keys to their TLS certificate secret names"
}

output "load_balancer_hostname" {
  value       = local.lb_hostname
  description = "Load balancer hostname (for CNAME records)"
}

output "load_balancer_ip" {
  value       = local.lb_ip
  description = "Load balancer IP address (for A records)"
}

output "lb_record_value" {
  value       = local.lb_record_value
  description = "The value to use in DNS records (hostname or IP)"
}

output "record_type" {
  value       = local.record_type
  description = "DNS record type (CNAME or A)"
}

output "name" {
  value       = local.name
  description = "The computed resource name"
}

output "base_domain" {
  value       = local.base_domain
  description = "The computed base domain"
}

output "base_subdomain" {
  value       = local.base_subdomain
  description = "The wildcard base subdomain"
}

output "username" {
  value       = local.username
  description = "Basic auth username (empty if disabled)"
}

output "password" {
  value       = local.password
  sensitive   = true
  description = "Basic auth password (empty if disabled)"
}

output "cloud_provider" {
  value       = local.cloud_provider
  description = "Detected cloud provider (AWS, GCP, AZURE)"
}

output "tenant_base_domain" {
  value       = local.tenant_base_domain
  description = "Tenant base domain from environment"
}

output "tenant_base_domain_id" {
  value       = local.tenant_base_domain_id
  description = "Route53 zone ID for the tenant base domain (empty if not AWS)"
}

output "legacy_resource_details" {
  value = concat(
    lookup(var.instance.spec, "basic_auth", false) ? [{
      name          = "Basic Authentication Password"
      value         = local.password
      resource_type = "ingress"
      resource_name = var.instance_name
      key           = var.instance_name
    }] : [],
    [{
      name          = "Base Domain"
      value         = local.base_domain
      resource_type = "ingress"
      resource_name = var.instance_name
      key           = var.instance_name
    }],
    [for k, v in lookup(var.instance.spec, "rules", {}) : {
      name          = "ingress domain"
      value         = lookup(v, "domain_prefix", null) == null || lookup(v, "domain_prefix", null) == "" ? local.base_domain : "${lookup(v, "domain_prefix", null)}.${local.base_domain}"
      resource_type = "ingress_rules_infra"
      resource_name = k
      key           = k
    }]
  )
}

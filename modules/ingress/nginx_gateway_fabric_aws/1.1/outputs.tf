locals {
  lb_hostname = module.nginx_gateway_fabric.load_balancer_hostname
  lb_ip       = module.nginx_gateway_fabric.load_balancer_ip
  output_attributes = {
    base_domain           = module.nginx_gateway_fabric.base_domain
    base_domain_enabled   = tostring(!lookup(var.instance.spec, "disable_base_domain", false))
    gateway_class         = module.nginx_gateway_fabric.gateway_class
    gateway_name          = module.nginx_gateway_fabric.gateway_name
    loadbalancer_hostname = local.lb_hostname
    loadbalancer_ip       = local.lb_ip
    loadbalancer_dns      = coalesce(local.lb_hostname, local.lb_ip, "")
  }
  output_interfaces = module.nginx_gateway_fabric.output_interfaces
}

output "domains" {
  value = module.nginx_gateway_fabric.domains
}

output "nginx_gateway_fabric" {
  value = module.nginx_gateway_fabric.nginx_gateway_fabric
}

output "domain" {
  value = module.nginx_gateway_fabric.domain
}

output "secure_endpoint" {
  value = module.nginx_gateway_fabric.secure_endpoint
}

output "gateway_class" {
  value       = module.nginx_gateway_fabric.gateway_class
  description = "The GatewayClass name used by this gateway"
}

output "gateway_name" {
  value       = module.nginx_gateway_fabric.gateway_name
  description = "The Gateway resource name"
}

output "subdomain" {
  value = module.nginx_gateway_fabric.subdomain
}

output "tls_secret" {
  value       = module.nginx_gateway_fabric.tls_secret
  description = "Map of domain keys to their TLS certificate secret names"
}

output "load_balancer_hostname" {
  value       = module.nginx_gateway_fabric.load_balancer_hostname
  description = "Load balancer hostname (for CNAME records)"
}

output "load_balancer_ip" {
  value       = module.nginx_gateway_fabric.load_balancer_ip
  description = "Load balancer IP address (for A records)"
}

output "legacy_resource_details" {
  value = module.nginx_gateway_fabric.legacy_resource_details
}

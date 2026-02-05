# Extract spec and advanced configuration
locals {
  spec            = var.instance.spec
  advanced_config = lookup(lookup(var.instance, "advanced", {}), "gcp_alb", {})
  metadata        = lookup(var.instance, "metadata", {})

  # Cloud provider and basic configuration
  tenant_provider        = lower(lookup(var.inputs.cloud_account.attributes, "tenant_provider", "aws"))
  use_internal_static_ip = lookup(local.advanced_config, "use_internal_static_ip", false)
  stack_name             = lookup(var.inputs.cloud_account.attributes, "stack_name", "default")
  cluster_name           = lookup(var.inputs.kubernetes_cluster.attributes, "cluster_name", lookup(var.inputs.kubernetes_cluster.attributes, "name", "default"))

  # Domain configuration
  tenant_base_domain    = lookup(var.inputs.cloud_account.attributes, "tenant_base_domain", "example.com")
  tenant_base_domain_id = lookup(var.inputs.cloud_account.attributes, "tenant_base_domain_id", "")
  instance_env_name     = length(var.environment.unique_name) + length(var.instance_name) + length(local.tenant_base_domain) >= 60 ? substr(md5("${var.instance_name}-${var.environment.unique_name}"), 0, 20) : "${var.instance_name}-${var.environment.unique_name}"
  base_domain           = lower("${var.instance_name}-${var.environment.unique_name}.${local.tenant_base_domain}") # domains are to be always lowercase
  subdomains            = "*.${local.base_domain}"

  # Feature flags
  ipv6               = lookup(var.instance.spec, "ipv6_enabled", false)
  enable_internal_lb = lookup(var.instance.spec, "private", false)

  # DNS configuration
  dns                 = lookup(local.advanced_config, "dns", {})
  custom_record_type  = lookup(local.dns, "record_type", "")
  dns_record_value    = lookup(local.dns, "record_value", "")
  custom_record_value = split(",", local.dns_record_value)

  # Load balancer configuration
  # the below logic is explained in clickup for https internal loadbalancing
  internal_lb       = lookup(var.instance.spec, "private", false) ? false : true
  force_redirection = local.internal_lb && lookup(var.instance.spec, "force_ssl_redirection", false) ? true : false
  internal_lb_ipv6  = local.internal_lb && local.ipv6 ? true : false

  # SSL/TLS configuration
  ssl_policy                      = lookup(local.advanced_config, "ssl_policy", {})
  existing_ssl_policy             = lookup(local.advanced_config, "existing_ssl_policy", null)
  managed_certificates            = local.internal_lb && lookup(local.advanced_config, "certificate_type", "") == "managed" ? true : false
  k8s_certificates                = lookup(local.advanced_config, "certificate_type", "") == "k8s" ? true : false
  enable_certificate_auto_renewal = lookup(local.advanced_config, "enable_certificate_auto_renewal", false)
  auto_renew_certificates         = local.enable_certificate_auto_renewal && local.k8s_certificates ? true : false

  # Domains and routing
  add_base_domain = {
    "defaultBase" = {
      "domain"                = "${local.base_domain}"
      "alias"                 = "default"
      "certificate_reference" = local.auto_renew_certificates ? lower("ingress-cert-${var.instance_name}") : null
    }
  }

  domains               = merge(var.instance.spec.domains, local.add_base_domain)
  rules_inside_domains  = flatten([for xx in local.domains : [for rule in lookup(xx, "rules", {}) : [merge(rule, xx), []][length(lookup(xx, "rules", {})) > 0 ? 0 : 1]]])
  rules_outside_domains = flatten([for xx in local.domains : [for rule in var.instance.spec.rules : [merge(rule, xx), []][length(lookup(xx, "rules", {})) <= 0 ? 0 : 1]]])
  ingress               = concat(local.rules_outside_domains, local.rules_inside_domains)
  ingressObjects        = { for k, v in flatten(local.ingress) : k => v if v.service_name != "" }
  ingressDetails        = { for k, v in var.instance.spec.domains : k => v }
  domainList            = distinct([for i in local.ingressObjects : lookup(i, "domain_prefix", "") == "" ? "${i.domain}" : "${lookup(i, "domain_prefix", "")}.${i.domain}"])

  # Ingress class and annotations
  ingress_class = local.enable_internal_lb ? "gce-internal" : "gce"

  common_annotations = merge({
    # https://cloud.google.com/kubernetes-engine/docs/how-to/internal-load-balance-ingress#deploy-ingress
    "kubernetes.io/ingress.class" = local.ingress_class
    },
    local.managed_certificates ? {
      "networking.gke.io/managed-certificates" = "${kubernetes_manifest.google_managed_certificates[0].manifest.metadata.name}"
      } : local.k8s_certificates ? {} : {
      "ingress.gcp.kubernetes.io/pre-shared-cert" = join(",", flatten([for key, value in local.ingressDetails : value[*].certificate_reference]))
      "kubernetes.io/ingress.allow-http"          = false
    }
  )

  name = lower(var.environment.namespace == "default" ? "${var.instance_name}" : "${var.environment.namespace}-${var.instance_name}")

  cert_manager_annotations = merge(
    { // default cert manager annotations
      "cert-manager.io/cluster-issuer" : "letsencrypt-prod-http01"
      "acme.cert-manager.io/http01-edit-in-place" : "true"
      "cert-manager.io/renew-before" : lookup(local.advanced_config, "renew_cert_before", "720h") // 30days; value must be parsable by https://pkg.go.dev/time#ParseDuration
    },
    { // overriding common annotations from instance.metadata
      for key, value in lookup(local.metadata, "annotations", {}) :
      key => value if can(regex("^cert-manager\\.io", key))
    }
  )

  annotations = merge(local.common_annotations, lookup(local.metadata, "annotations", {}),
    local.enable_internal_lb ? {
      "networking.gke.io/internal-load-balancer-allow-global-access" = "true"
    } : {},
    lookup(var.instance.spec, "grpc", false) ? {
      "cloud.google.com/app-protocols" = "{\"http\":\"HTTP2\",\"https\":\"HTTP2\"}"
    } : {},
    local.force_redirection ? {
      "networking.gke.io/v1beta1.FrontendConfig" = "${lower(var.instance_name)}-gcp-frontend-redirect"
    } : {},
    local.ipv6 && local.internal_lb_ipv6 ? {
      "kubernetes.io/ingress.global-static-ip-name" : "${google_compute_global_address.lb-ipv6[0].name}"
    } : {},
    local.auto_renew_certificates ? local.cert_manager_annotations : {},
    local.use_internal_static_ip ? {
      "kubernetes.io/ingress.regional-static-ip-name" = "${google_compute_address.internal[0].name}"
    } : {}
  )

  sslPolicy = local.existing_ssl_policy != null ? local.existing_ssl_policy : local.ssl_policy != {} ? google_compute_ssl_policy.custom-ssl-policy[0].name : null

  # Ingress objects grouped by host
  ingress_objects_with_hosts = {
    for k, v in local.ingressObjects : k => merge(v, {
      host = lookup(v, "domain_prefix", "") == "" || lookup(v, "domain_prefix", null) == null ? lookup(v, "fqdn", null) == null || lookup(v, "fqdn", null) == "" ? "${v.domain}" : lookup(v, "fqdn", null) : "${lookup(v, "domain_prefix", "")}.${v.domain}"
    })
  }

  distinct_hosts = distinct([for k, v in local.ingress_objects_with_hosts : v.host])

  ingress_objects_grouped_by_host = {
    for host in local.distinct_hosts : host => {
      for k, v in local.ingress_objects_with_hosts : k => v if v.host == host
    }
  }
}

# Output attributes and interfaces
locals {
  output_attributes = {
    base_domain = local.base_domain
  }

  output_interfaces = local.ingress_interfaces
}

# Ingress interface calculation (inline from ingress_interface utility module)
locals {
  is_auth_enabled = false # GCP ALB module doesn't have username/password support in current implementation

  inside_rules = [for domain_key, domain in local.domains : {
    for rule_key, rule in lookup(domain, "rules", {}) : domain_key == "defaultBase" ? "facets_${rule_key}" : "${domain_key}_${rule_key}" => {
      host = length(lookup(rule, "domain_prefix", {})) > 0 ? "${rule.domain_prefix}.${domain.domain}" : "${domain.domain}"
    } if rule.service_name != ""
  }]

  outside_rules = [for domain_key, domain in local.domains : {
    for rule_key, rule in var.instance.spec.rules : domain_key == "defaultBase" ? "facets_${rule_key}" : "${domain_key}_${rule_key}" => {
      host = length(lookup(rule, "domain_prefix", {})) > 0 ? "${rule.domain_prefix}.${domain.domain}" : "${domain.domain}"
    } if rule.service_name != ""
  }]

  merge_concat_rules = merge(concat(local.inside_rules, local.outside_rules)...)

  ingress_interfaces = {
    for rule_key, rule in local.merge_concat_rules : rule_key => {
      connection_string = local.is_auth_enabled ? "https://username:password@${rule.host}:443" : "https://${rule.host}:443"
      host              = rule.host
      port              = 443
      username          = ""
      password          = ""
      secrets           = []
    }
  }
}

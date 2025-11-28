output "legacy_resource_details" {
  value = concat(
    lookup(var.instance.spec, "basicAuth", lookup(var.instance.spec, "basic_auth", false)) ? [{
      name          = "Basic Authentication Password"
      value         = random_string.basic-auth-pass[0].result
      resource_type = "ingress"
      resource_name = var.instance_name
      key           = var.instance_name
    }] : [],
    # Only include base domain if not disabled
    !lookup(var.instance.spec, "disable_base_domain", false) ? [{
      name          = "Base Domain"
      value         = local.base_domain
      resource_type = "ingress"
      resource_name = var.instance_name
      key           = var.instance_name
      }
    ] : [],
    [for k, v in var.instance.spec.rules : {
      name = "ingress domain"
      # Use rule's domain if base domain is disabled, otherwise use base domain logic
      value = lookup(v, "disable", false) == false ? (
        !lookup(var.instance.spec, "disable_base_domain", false) ? (
          lookup(v, "domain_prefix", null) == null || lookup(v, "domain_prefix", null) == "" ? "${local.base_domain}" : "${lookup(v, "domain_prefix", null)}.${local.base_domain}"
          ) : (
          # When base domain is disabled, we need to use the domain from the rule's domain configuration
          lookup(v, "domain_prefix", null) == null || lookup(v, "domain_prefix", null) == "" ?
          lookup(lookup(local.domains, lookup(v, "domain_key", ""), {}), "domain", "no-domain-configured") :
          "${lookup(v, "domain_prefix", null)}.${lookup(lookup(local.domains, lookup(v, "domain_key", ""), {}), "domain", "no-domain-configured")}"
        )
      ) : ""
      resource_type = "ingress_rules_infra"
      resource_name = k
      key           = k
    } if lookup(v, "disable", false) == false]
  )
}

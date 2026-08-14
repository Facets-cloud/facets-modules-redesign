# Control-plane metadata (tenant provider + base domain) — read the same way as the
# base module. Computed here in the wrapper so base_domain can be derived WITHOUT
# depending on the base module's outputs (that would create a cycle: base_domain →
# ssl-cert annotation → base module input).
data "external" "cc_env" {
  program = ["sh", "-c", <<-EOT
    echo "{\"cc_tenant_provider\":\"$TF_VAR_cc_tenant_provider\",\"tenant_base_domain\":\"$TF_VAR_tenant_base_domain\"}"
  EOT
  ]
}

# Route53 zone for the tenant base domain (AWS only) — target zone for the base
# domain ACM certificate's DNS validation records. Lives in the tooling account.
data "aws_route53_zone" "base_domain_zone" {
  count    = local.tenant_provider == "aws" ? 1 : 0
  name     = local.tenant_base_domain
  provider = aws3tooling
}

locals {
  # Compute name the same way as the base module (needed for ACM secret names)
  name = lower(var.environment.namespace == "default" ? var.instance_name : "${var.environment.namespace}-${var.instance_name}")

  # Control-plane metadata (same derivation as the base module)
  cc_tenant_provider    = data.external.cc_env.result.cc_tenant_provider
  tenant_base_domain    = data.external.cc_env.result.tenant_base_domain
  tenant_provider       = lower(local.cc_tenant_provider != "" ? local.cc_tenant_provider : "aws")
  tenant_base_domain_id = length(data.aws_route53_zone.base_domain_zone) > 0 ? data.aws_route53_zone.base_domain_zone[0].zone_id : ""

  # Base domain — MUST stay byte-for-byte in sync with the base module's
  # computation (facets-utility-modules//nginx_gateway_fabric: instance_env_name /
  # check_domain_prefix / base_domain). A mismatch would issue the base ACM cert
  # for the wrong host.
  instance_env_name   = length(var.environment.unique_name) + length(var.instance_name) + length(local.tenant_base_domain) >= 60 ? substr(md5("${var.instance_name}-${var.environment.unique_name}"), 0, 20) : "${var.instance_name}-${var.environment.unique_name}"
  check_domain_prefix = coalesce(lookup(var.instance.spec, "domain_prefix_override", null), local.instance_env_name)
  base_domain         = lower("${local.check_domain_prefix}.${local.tenant_base_domain}")
  base_subdomain      = "*.${local.base_domain}"

  # Detect domains with ACM ARN as certificate_reference
  acm_cert_domains = {
    for domain_key, domain in lookup(var.instance.spec, "domains", {}) :
    domain_key => domain
    if can(domain.certificate_reference) && length(regexall("arn:aws:acm:", lookup(domain, "certificate_reference", ""))) > 0
  }

  # K8s secret name for ACM cert domains — the ACK Certificate CRD exports cert to this secret
  acm_cert_secret_names = {
    for domain_key, domain in local.acm_cert_domains :
    domain_key => "${local.name}-${domain_key}-acm-tls"
  }

  # Detect ACK ACM controller availability
  use_ack_acm = try(var.inputs.ack_acm_controller_details, null) != null

  # ACM mode: when ACM domains exist but no ACK controller,
  # TLS terminates at the NLB instead of at the Gateway pod
  acm_mode = !local.use_ack_acm && length(local.acm_cert_domains) > 0

  # Auto-issue an ACM cert for the base domain whenever TLS terminates at the NLB
  # (acm_mode) and the base domain is active on AWS. The base domain carries no
  # certificate_reference, so without this it would contribute no ARN to the
  # ssl-cert annotation → base-domain HTTPS falls back to the NLB default cert and
  # fails hostname validation. When acm_mode is false, the base domain keeps using
  # cert-manager (unchanged), so no base ACM cert is needed.
  base_acm_enabled = local.acm_mode && !lookup(var.instance.spec, "disable_base_domain", false) && local.tenant_provider == "aws"

  # ACM ARNs to attach to NLB for TLS termination — user-supplied ARNs plus the
  # auto-issued base-domain cert (validated ARN, so the NLB never attaches an
  # unvalidated certificate).
  acm_cert_arns = local.acm_mode ? distinct(concat(
    [for domain_key, domain in local.acm_cert_domains : domain.certificate_reference],
    local.base_acm_enabled ? [aws_acm_certificate_validation.base_acm[0].certificate_arn] : []
  )) : []

  # Rewrite ACM ARN certificate_reference → K8s secret name for all ACM domains.
  # In ACM mode (no ACK), this rewrite is harmless — external_tls_termination=true
  # tells the base module to ignore certificate_reference entirely.
  # Always rewriting avoids unknown map values when use_ack_acm is unresolved at plan time.
  modified_domains = {
    for domain_key, domain in lookup(var.instance.spec, "domains", {}) :
    domain_key => contains(keys(local.acm_cert_secret_names), domain_key) ? merge(domain, {
      certificate_reference = local.acm_cert_secret_names[domain_key]
    }) : domain
  }

  # Build modified instance with rewritten domains
  modified_instance = merge(var.instance, {
    spec = merge(var.instance.spec, {
      domains = local.modified_domains
    })
  })

  # ALB controller dependency label — creates implicit Terraform dependency
  alb_controller_helm_release_id = try(var.inputs.aws_alb_controller_details.attributes.helm_release_id, "")

  # LoadBalancerClass: ALB controller present → service.k8s.aws/nlb, absent (EKS Auto Mode) → eks.amazonaws.com/nlb
  load_balancer_class = local.alb_controller_helm_release_id != "" ? "service.k8s.aws/nlb" : "eks.amazonaws.com/nlb"

  # AWS NLB annotations
  aws_annotations = merge(
    lookup(var.instance.spec, "private", false) ? {
      "service.beta.kubernetes.io/aws-load-balancer-scheme"   = "internal"
      "service.beta.kubernetes.io/aws-load-balancer-internal" = "true"
      } : {
      "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
    },
    {
      "service.beta.kubernetes.io/aws-load-balancer-type"                    = "external"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"         = "ip"
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"        = "tcp"
      "service.beta.kubernetes.io/aws-load-balancer-target-group-attributes" = lookup(var.instance.spec, "private", false) ? "proxy_protocol_v2.enabled=true,preserve_client_ip.enabled=false" : "proxy_protocol_v2.enabled=true,preserve_client_ip.enabled=true"
    },
    # ACM mode: attach ACM certs to NLB for TLS termination
    local.acm_mode ? {
      "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"  = join(",", local.acm_cert_arns)
      "service.beta.kubernetes.io/aws-load-balancer-ssl-ports" = "443"
    } : {}
  )

  # ACK ACM Certificate CRD resources — creates ACM certificates via ACK controller
  # and exports them to K8s TLS secrets for Gateway listener consumption.
  # Only created when ACK controller is available.
  ack_acm_resources = local.use_ack_acm ? {
    for domain_key, domain in local.acm_cert_domains :
    "ack-acm-cert-${domain_key}" => {
      apiVersion = "acm.services.k8s.aws/v1alpha1"
      kind       = "Certificate"
      metadata = {
        name      = "${local.name}-acm-cert-${domain_key}"
        namespace = var.environment.namespace
      }
      spec = {
        domainName = "*.${domain.domain}"
        subjectAlternativeNames = [
          domain.domain,
          "*.${domain.domain}"
        ]
        validationMethod = "DNS"
        options = {
          certificateTransparencyLoggingPreference = "ENABLED"
        }
        exportTo = {
          namespace = var.environment.namespace
          name      = local.acm_cert_secret_names[domain_key]
          key       = "tls.crt"
        }
      }
    }
  } : {}
}

# Call the base utility module
module "nginx_gateway_fabric" {
  source = "github.com/Facets-cloud/facets-utility-modules//nginx_gateway_fabric"

  instance      = local.modified_instance
  instance_name = var.instance_name
  environment   = var.environment
  inputs        = var.inputs

  service_annotations = merge(local.aws_annotations,
    local.alb_controller_helm_release_id != "" ? {
      "facets.cloud/aws-alb-controller-release" = local.alb_controller_helm_release_id
    } : {}
  )

  load_balancer_class      = local.load_balancer_class
  external_tls_termination = local.acm_mode

  nginx_proxy_extra_config = {
    rewriteClientIP = {
      mode = "ProxyProtocol"
      trustedAddresses = [{
        type  = "CIDR"
        value = "0.0.0.0/0"
      }]
    }
  }

  additional_base_resources = local.ack_acm_resources
}

# Pre-create empty TLS secrets for ACK ACM certificate export
# ACK ACM controller requires the target secret to exist before it can export
# Only created when ACK controller is available
resource "kubernetes_secret_v1" "acm_cert" {
  for_each = local.use_ack_acm ? local.acm_cert_domains : {}

  metadata {
    name      = local.acm_cert_secret_names[each.key]
    namespace = var.environment.namespace
  }

  data = {
    "tls.crt" = ""
    "tls.key" = ""
  }

  type = "kubernetes.io/tls"

  lifecycle {
    ignore_changes = [data, metadata[0].annotations, metadata[0].labels]
  }
}

# --- Auto-issued base-domain ACM certificate ---
# Issued when TLS terminates at the NLB (acm_mode) and the base domain is active.
# Covers base_domain + *.base_domain; its validated ARN is appended to the NLB
# ssl-cert annotation via local.acm_cert_arns, so the base domain always has a
# matching certificate without relying on cert-manager.
#
# Provider split (cross-account): the certificate is issued in the DEFAULT aws
# provider (workload account + region, where the NLB lives — an ACM cert attached
# to an NLB must be in the same account/region), while its DNS validation records
# are written to the tooling account's Route53 zone via aws3tooling.
resource "aws_acm_certificate" "base_acm" {
  count                     = local.base_acm_enabled ? 1 : 0
  domain_name               = local.base_domain
  subject_alternative_names = [local.base_subdomain]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [options]
  }
}

resource "aws_route53_record" "base_acm_validation" {
  # Key by the domain names we requested (known at plan time). Keying off
  # domain_validation_options fails for a brand-new cert — ACM computes the whole
  # set at apply, so for_each can't resolve its keys. Record values are looked up
  # per key from the computed set (may be unknown at plan — that's fine). ACM can
  # emit the same CNAME for apex + wildcard; allow_overwrite handles the duplicate.
  for_each = local.base_acm_enabled ? toset([local.base_domain, local.base_subdomain]) : toset([])

  allow_overwrite = true
  name = one([
    for d in aws_acm_certificate.base_acm[0].domain_validation_options :
    d.resource_record_name if d.domain_name == each.key
  ])
  records = [one([
    for d in aws_acm_certificate.base_acm[0].domain_validation_options :
    d.resource_record_value if d.domain_name == each.key
  ])]
  type = one([
    for d in aws_acm_certificate.base_acm[0].domain_validation_options :
    d.resource_record_type if d.domain_name == each.key
  ])
  ttl      = 60
  zone_id  = local.tenant_base_domain_id
  provider = aws3tooling
}

resource "aws_acm_certificate_validation" "base_acm" {
  count                   = local.base_acm_enabled ? 1 : 0
  certificate_arn         = aws_acm_certificate.base_acm[0].arn
  validation_record_fqdns = [for r in aws_route53_record.base_acm_validation : r.fqdn]
}

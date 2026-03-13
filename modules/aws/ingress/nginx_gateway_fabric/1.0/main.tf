locals {
  # Compute name the same way as the base module (needed for ACM secret names)
  name = lower(var.environment.namespace == "default" ? var.instance_name : "${var.environment.namespace}-${var.instance_name}")

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

  # Rewrite instance domains: replace ACM ARN certificate_reference with K8s secret name
  # The base module only sees K8s secret names — never ACM ARNs
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
    }
  )
}

# Call the base utility module
module "nginx_gateway_fabric" {
  source = "github.com/Facets-cloud/facets-utility-modules//nginx_gateway_fabric?ref=nginx-gateway-fabric-base"

  instance      = local.modified_instance
  instance_name = var.instance_name
  environment   = var.environment
  inputs        = var.inputs

  service_annotations = merge(local.aws_annotations,
    local.alb_controller_helm_release_id != "" ? {
      "facets.cloud/aws-alb-controller-release" = local.alb_controller_helm_release_id
    } : {}
  )

  load_balancer_class = local.load_balancer_class

  nginx_proxy_extra_config = {
    rewriteClientIP = {
      mode = "ProxyProtocol"
      trustedAddresses = [{
        type  = "CIDR"
        value = "0.0.0.0/0"
      }]
    }
  }
}

# ACK ACM Certificate CRD resources — creates ACM certificates via ACK controller
# and exports them to K8s TLS secrets for Gateway listener consumption.
# Only created for domains whose certificate_reference is an ACM ARN.
# Requires the ack_acm_controller to be deployed (optional input).
module "ack_acm_certificate" {
  for_each = local.acm_cert_domains

  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${local.name}-acm-cert-${each.key}"
  namespace       = var.environment.namespace
  advanced_config = {}

  data = {
    apiVersion = "acm.services.k8s.aws/v1alpha1"
    kind       = "Certificate"
    metadata = {
      name      = "${local.name}-acm-cert-${each.key}"
      namespace = var.environment.namespace
    }
    spec = {
      domainName = "*.${each.value.domain}"
      subjectAlternativeNames = [
        each.value.domain,
        "*.${each.value.domain}"
      ]
      validationMethod = "DNS"
      options = {
        certificateTransparencyLoggingPreference = "ENABLED"
      }
      exportTo = {
        namespace = var.environment.namespace
        name      = local.acm_cert_secret_names[each.key]
        key       = "tls.crt"
      }
    }
  }
}

# Pre-create empty TLS secrets for ACK ACM certificate export
# ACK ACM controller requires the target secret to exist before it can export
resource "kubernetes_secret_v1" "acm_cert" {
  for_each = local.acm_cert_domains

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

locals {
  # Detect domains whose certificate_reference is an ACM ARN
  acm_cert_domains = {
    for domain_key, domain in lookup(var.instance.spec, "domains", {}) :
    domain_key => domain
    if can(domain.certificate_reference) && length(regexall("arn:aws:acm:", lookup(domain, "certificate_reference", ""))) > 0
  }

  # ACM mode: ACM ARNs present → terminate TLS at the NLB (not the Gateway). All other
  # domains use the base module's cert-manager HTTP-01 + ListenerSet path.
  acm_mode = length(local.acm_cert_domains) > 0

  acm_cert_arns = local.acm_mode ? distinct([
    for domain_key, domain in local.acm_cert_domains : domain.certificate_reference
  ]) : []

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

  # Private LB → HTTP-01 can't validate an internal LB; issue certs via the named
  # DNS-01 ClusterIssuer instead (cnameStrategy Follow). No effect in acm_mode.
  private                 = lookup(var.instance.spec, "private", false)
  dns01_issuer            = lookup(var.instance.spec, "dns01_cluster_issuer", "")
  cluster_issuer_override = local.private && !local.acm_mode && local.dns01_issuer != "" ? local.dns01_issuer : lookup(var.instance.spec, "cluster_issuer_override", null)

  # Private + DNS-01 (non-ACM): one wildcard cert [domain, *.domain] per domain (single DNS-01
  # challenge) via the listenerset-shim, instead of per-hostname HTTP-01 certs.
  wildcard_tls = local.private && !local.acm_mode && local.dns01_issuer != ""

  modified_instance = merge(var.instance, {
    spec = merge(var.instance.spec, {
      cluster_issuer_override = local.cluster_issuer_override
      wildcard_tls            = local.wildcard_tls
    })
  })
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
}

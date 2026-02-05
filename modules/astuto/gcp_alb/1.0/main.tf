################################################################################
# Kubernetes Secret for DNS (GCP)
################################################################################

data "kubernetes_secret_v1" "dns" {
  count = local.tenant_provider == "aws" ? 0 : 1
  metadata {
    name      = "facets-tenant-dns"
    namespace = "default"
  }
}

################################################################################
# SSL Policy
################################################################################

resource "google_compute_ssl_policy" "custom-ssl-policy" {
  count           = local.ssl_policy != {} ? 1 : 0
  name            = lookup(local.ssl_policy, "name", "ssl-policy")
  min_tls_version = lookup(local.ssl_policy, "tls_version", "TLS_1_2")
}

################################################################################
# HTTPS Redirect FrontendConfig
################################################################################

resource "kubernetes_manifest" "https_redirect" {
  count = local.force_redirection ? 1 : 0
  manifest = {
    apiVersion = "networking.gke.io/v1beta1"
    kind       = "FrontendConfig"
    metadata = {
      name      = "${lower(var.instance_name)}-gcp-frontend-redirect"
      namespace = lookup(local.metadata, "namespace", var.environment.namespace)
    }
    spec = merge({
      redirectToHttps = {
        enabled          = true
        responseCodeName = "MOVED_PERMANENTLY_DEFAULT"
      }
    }, jsondecode(local.sslPolicy != null ? jsonencode({ sslPolicy = local.sslPolicy }) : jsonencode({})))
  }
}

################################################################################
# Google Managed Certificates
################################################################################

resource "kubernetes_manifest" "google_managed_certificates" {
  count = local.managed_certificates ? 1 : 0 # create this resource if enable_managed_certificates is true
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"
    metadata = {
      name      = "${lower(var.instance_name)}-managed-cert"
      namespace = lookup(local.metadata, "namespace", var.environment.namespace)
    }
    spec = {
      domains = tolist([for i in local.domainList : i if length(i) < 64])
    }
  }
  # On mpl request, disabling any changes whatsoever
  lifecycle {
    ignore_changes = ["manifest"]
  }
}

################################################################################
# Let's Encrypt Certificate Generation
################################################################################

resource "tls_private_key" "private_key" {
  count     = local.auto_renew_certificates ? 0 : 1
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  count           = local.auto_renew_certificates ? 0 : 1
  account_key_pem = tls_private_key.private_key[0].private_key_pem
  email_address   = "rohit.raveendran@capillarytech.com"
}

resource "acme_certificate" "certificate" {
  count           = local.auto_renew_certificates ? 0 : 1
  account_key_pem = acme_registration.reg[0].account_key_pem
  common_name     = local.base_domain
  subject_alternative_names = [
    local.subdomains
  ]
  min_days_remaining = 30

  dynamic "dns_challenge" {
    for_each = local.tenant_provider == "aws" ? toset(["aws"]) : toset([])
    content {
      provider = "route53"
    }
  }

  dynamic "dns_challenge" {
    for_each = local.tenant_provider == "google" ? toset(["gcloud"]) : toset([])
    content {
      provider = "gcloud"
      config = {
        GCE_PROJECT         = lookup(try(data.kubernetes_secret_v1.dns[0].data, {}), "project", "")
        GCE_SERVICE_ACCOUNT = lookup(lookup(try(data.kubernetes_secret_v1.dns[0], {}), "data", {}), "credentials.json", "{}")
      }
    }
  }

  recursive_nameservers = [
    "8.8.8.8:53"
  ]

  lifecycle {
    ignore_changes = [dns_challenge]
  }
}

################################################################################
# Certificate stored in Kubernetes Secret
################################################################################

resource "kubernetes_secret" "cert-secret" {
  count = local.auto_renew_certificates ? 0 : 1
  metadata {
    name      = lower("alb-ingress-cert-${var.instance_name}")
    namespace = lookup(local.metadata, "namespace", var.environment.namespace)
  }
  data = {
    "tls.crt" = "${acme_certificate.certificate[0].certificate_pem}${acme_certificate.certificate[0].issuer_pem}"
    "tls.key" = acme_certificate.certificate[0].private_key_pem
    "ca.crt"  = acme_certificate.certificate[0].issuer_pem
  }
  type = "kubernetes.io/tls"
}

################################################################################
# Route53 DNS Records (AWS)
################################################################################

resource "aws_route53_record" "cluster-base-domain" {
  count = local.tenant_provider == "aws" && local.tenant_base_domain_id != "" ? 1 : 0
  depends_on = [
    kubernetes_ingress_v1.example_ingress
  ]
  zone_id = local.tenant_base_domain_id
  name    = local.base_domain
  type    = local.custom_record_type != "" ? local.custom_record_type : local.ipv6 ? "AAAA" : "A"
  ttl     = "300"
  records = local.dns_record_value != "" ? local.custom_record_value : [
    kubernetes_ingress_v1.example_ingress.status.0.load_balancer.0.ingress.0.ip
  ]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "cluster-base-domain-wildcard" {
  count = local.tenant_provider == "aws" && local.tenant_base_domain_id != "" ? 1 : 0
  depends_on = [
    kubernetes_ingress_v1.example_ingress
  ]
  zone_id = local.tenant_base_domain_id
  name    = local.subdomains
  type    = local.custom_record_type != "" ? local.custom_record_type : local.ipv6 ? "AAAA" : "A"
  ttl     = "300"
  records = local.dns_record_value != "" ? local.custom_record_value : [
    kubernetes_ingress_v1.example_ingress.status.0.load_balancer.0.ingress.0.ip
  ]

  lifecycle {
    prevent_destroy = true
  }
}

################################################################################
# Kubernetes Ingress
################################################################################

resource "kubernetes_ingress_v1" "example_ingress" {
  wait_for_load_balancer = true
  depends_on = [
    acme_certificate.certificate, kubernetes_secret.cert-secret
  ]
  metadata {
    name        = lower(lookup(local.metadata, "name", var.instance_name))
    namespace   = lookup(local.metadata, "namespace", var.environment.namespace)
    annotations = local.annotations
    labels = {
      resource_type = "ingress"
      resource_name = var.instance_name
    }
  }
  spec {
    dynamic "default_backend" {
      for_each = lookup(local.advanced_config, "default_backend", null) != null ? [lookup(local.advanced_config, "default_backend", null)] : []
      content {
        service {
          name = default_backend.value.service
          port {
            number = default_backend.value.port
          }
        }
      }
    }

    dynamic "rule" {
      for_each = local.ingress_objects_grouped_by_host
      content {
        host = rule.key
        http {
          dynamic "path" {
            for_each = rule.value
            content {
              path      = path.value.path
              path_type = "Prefix"
              backend {
                service {
                  name = path.value.service_name
                  port {
                    name   = lookup(path.value, "port_name", null)
                    number = lookup(path.value, "port_name", null) != null ? null : lookup(path.value, "port", null)
                  }
                }
              }
            }
          }
        }
      }
    }

    dynamic "tls" {
      for_each = local.auto_renew_certificates ? [] : [0]
      content {
        hosts       = tolist([local.base_domain, local.subdomains])
        secret_name = kubernetes_secret.cert-secret[0].metadata[0].name
      }
    }

    dynamic "tls" {
      for_each = [local.ingressDetails, {}][local.k8s_certificates && !local.auto_renew_certificates ? 0 : 1]
      content {
        hosts       = tolist([lookup(tls.value, "domain", null), "*.${lookup(tls.value, "domain", null)}"])
        secret_name = lookup(tls.value, "certificate_reference", null) == null ? kubernetes_secret.cert-secret[0].metadata[0].name : lookup(tls.value, "certificate_reference", kubernetes_secret.cert-secret[0].metadata[0].name)
      }
    }

    dynamic "tls" {
      for_each = [local.ingress_objects_grouped_by_host, {}][local.auto_renew_certificates ? 0 : 1]
      content {
        hosts       = tolist([tls.key])
        secret_name = lookup(tls.value, "domain_prefix", null) == null || lookup(tls.value, "domain_prefix", null) == "" ? lower("${var.instance_name}-${tls.key}") : lower("${var.instance_name}-${tls.key}-${tls.value.domain_prefix}")
      }
    }
  }
}

################################################################################
# Global IPv6 Address
################################################################################

resource "google_compute_global_address" "lb-ipv6" {
  count        = local.ipv6 && local.internal_lb_ipv6 ? 1 : 0
  name         = length(lower("${local.stack_name}-${local.cluster_name}-${var.instance_name}-lb-ipv6")) < 63 ? lower("${local.stack_name}-${local.cluster_name}-${var.instance_name}-lb-ipv6") : md5(lower("${local.stack_name}-${local.cluster_name}-${var.instance_name}-lb-ipv6"))
  address_type = "EXTERNAL"
  ip_version   = "IPV6"

  lifecycle {
    ignore_changes = [name]
  }
}

################################################################################
# Internal Static IP Address
################################################################################

resource "google_compute_address" "internal" {
  count        = local.use_internal_static_ip ? 1 : 0
  name         = length(lower("${local.stack_name}-${local.cluster_name}-${var.instance_name}-lb-ip")) < 63 ? lower("${local.stack_name}-${local.cluster_name}-${var.instance_name}-lb-ip") : md5(lower("${local.stack_name}-${local.cluster_name}-${var.instance_name}-lb-ip"))
  address_type = "INTERNAL"
  purpose      = "SHARED_LOADBALANCER_VIP"
  subnetwork   = lookup(lookup(var.inputs.network.attributes, "legacy_outputs", {}), "gcp_cloud", {})["subnetwork_id"]
}

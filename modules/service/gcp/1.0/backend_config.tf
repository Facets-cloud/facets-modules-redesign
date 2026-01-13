locals {
  backend_config            = lookup(local.gcp_advanced_config, "backend_config", {})
  enable_alb_backend_config = lookup(local.backend_config, "enabled", false)
  backendConfig = {
    apiVersion = "cloud.google.com/v1",
    kind       = "BackendConfig",
    spec = merge({
      healthCheck = {
        checkIntervalSec   = lookup(lookup(lookup(local.backend_config, "spec", {}), "healthCheck", {}), "checkIntervalSec", 10),
        timeoutSec         = lookup(lookup(lookup(local.backend_config, "spec", {}), "healthCheck", {}), "timeoutSec", lookup(lookup(local.runtime, "health_checks", {}), "timeout", 5)),
        healthyThreshold   = lookup(lookup(lookup(local.backend_config, "spec", {}), "healthCheck", {}), "healthyThreshold", 2),
        unhealthyThreshold = lookup(lookup(lookup(local.backend_config, "spec", {}), "healthCheck", {}), "unhealthyThreshold", 2),
        type               = lookup(lookup(lookup(local.backend_config, "spec", {}), "healthCheck", {}), "type", "HTTP"),
        requestPath        = lookup(lookup(lookup(local.backend_config, "spec", {}), "healthCheck", {}), "requestPath", lookup(lookup(local.runtime, "health_checks", {}), "readiness_url", "/")),
      }
    }, lookup(local.backend_config, "spec", {}))
  }
}

module "backend_config" {
  count           = local.enable_alb_backend_config ? 1 : 0
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  namespace       = local.namespace
  advanced_config = {}
  data            = local.backendConfig
  name            = lower(var.instance_name)
}
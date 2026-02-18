locals {
  name       = "${var.instance_name}-${var.environment.unique_name}"
  project_id = var.inputs.gcp_cloud_account.attributes.project_id
  region     = var.inputs.gcp_cloud_account.attributes.region

  # Parse CloudRun service references or use literal names
  # Format: ${service.name.out.attributes.service_name} or literal "my-service"
  parsed_services = merge(
    # Default services from domains
    {
      for key, config in var.instance.spec.domains :
      config.domain => lookup(config, "default_service", "")
    },
    # Path-specific services from domains
    flatten([
      for key, config in var.instance.spec.domains : [
        for path, path_config in lookup(config, "paths", {}) : {
          "${config.domain}${path}" = path_config.service
        }
      ]
    ])...
  )

  # Extract unique service names for backend creation
  unique_services = distinct([
    for service in values(local.parsed_services) : service if service != ""
  ])

  # Certificate configuration per domain
  certificates = {
    for key, config in var.instance.spec.domains :
    config.domain => {
      mode = lookup(lookup(config, "certificate", {}), "mode", "auto")
      cert_name = lookup(lookup(config, "certificate", {}), "mode", "auto") == "auto" ? "${local.name}-${substr(md5(config.domain), 0, 8)}" : (
        lookup(lookup(config, "certificate", {}), "mode", "auto") == "managed" ? lookup(lookup(config, "certificate", {}), "managed_cert_name", "${local.name}-${substr(md5(config.domain), 0, 8)}") : lookup(lookup(config, "certificate", {}), "existing_cert_name", "")
      )
      create_managed = contains(["auto", "managed"], lookup(lookup(config, "certificate", {}), "mode", "auto"))
    }
  }

  # All managed certificates to create
  managed_certs = {
    for domain, cert_config in local.certificates :
    cert_config.cert_name => domain
    if cert_config.create_managed
  }

  # Global config with defaults
  global_config  = lookup(var.instance.spec, "global_config", {})
  enable_cdn     = lookup(local.global_config, "enable_cdn", false)
  enable_iap     = lookup(local.global_config, "enable_iap", false)
  timeout_sec    = lookup(local.global_config, "timeout_sec", 30)
  custom_headers = lookup(local.global_config, "custom_headers", {})

  # Advanced config with defaults
  advanced_config             = lookup(var.instance.spec, "advanced", {})
  enable_http                 = lookup(local.advanced_config, "enable_http", true)
  http_redirect               = lookup(local.advanced_config, "http_redirect", true)
  session_affinity            = lookup(local.advanced_config, "session_affinity", "NONE")
  connection_draining_timeout = lookup(local.advanced_config, "connection_draining_timeout", 300)

  # Tags
  labels = merge(
    var.environment.cloud_tags,
    {
      managed_by  = "facets"
      environment = var.environment.name
      instance    = var.instance_name
    }
  )
}

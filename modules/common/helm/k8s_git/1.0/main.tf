locals {
  spec = var.instance.spec

  # Extract values using lookup with appropriate defaults
  release_name   = lookup(local.spec, "release_name", module.helm_release_name.name)
  git_base_url   = lookup(local.spec, "git_base_url", "github.com")
  git_repository = lookup(local.spec, "git_repository", "")
  git_owner      = lookup(local.spec, "git_owner", "")
  git_username   = lookup(local.spec, "git_username", "")
  git_token      = lookup(local.spec, "git_token", "")
  chart_path     = lookup(local.spec, "chart_path", "")
  git_ref        = lookup(local.spec, "git_ref", "main")
  namespace      = lookup(local.spec, "namespace", var.environment.namespace)
  wait_config    = lookup(local.spec, "wait_config", {})
  values         = lookup(local.spec, "values", {})

  # Wait configuration with defaults
  wait_enabled = lookup(local.wait_config, "wait", true)
  wait_timeout = lookup(local.wait_config, "timeout", 300)

  # Git repository URL with authentication
  git_url = "https://${local.git_username}:${local.git_token}@${local.git_base_url}/${local.git_owner}/${local.git_repository}.git"

  # Local chart directory path
  local_chart_directory = "charts/${local.git_repository}"
  chart_directory       = "${path.module}/${local.local_chart_directory}"
}

module "helm_release_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  is_k8s          = true
  globally_unique = false
  resource_name   = var.instance_name
  resource_type   = "helm"
  limit           = 53
  environment     = var.environment
}

# Clone Git repository using external data source with script file
data "external" "git_clone" {
  program = ["bash", "${path.module}/git_clone.sh"]

  query = {
    git_url    = local.git_url
    git_ref    = local.git_ref
    chart_dir  = local.chart_directory
    chart_path = local.chart_path
  }
}

# Deploy Helm chart from cloned directory
resource "helm_release" "git_chart" {
  name      = local.release_name
  chart     = data.external.git_clone.result.chart_path
  version   = data.external.git_clone.result.chart_version
  namespace = local.namespace

  create_namespace = true

  wait    = local.wait_enabled
  timeout = local.wait_timeout

  values = [
    yamlencode(local.values)
  ]
}

locals {
  spec          = var.instance.spec
  namespace     = lookup(var.instance.metadata, "namespace", null) == null ? var.environment.namespace : var.instance.metadata.namespace
  annotations   = lookup(var.instance.metadata, "annotations", {})
  labels        = lookup(var.instance.metadata, "labels", {})
  resource_type = "service"
  resource_name = var.instance_name
  sa_name       = lower(var.instance_name)

  from_artifactories      = lookup(lookup(lookup(var.inputs, "artifactories", {}), "attributes", {}), "registry_secrets_list", [])
  from_kubernetes_cluster = lookup(lookup(lookup(lookup(var.inputs, "kubernetes_details", {}), "attributes", {}), "legacy_outputs", {}), "registry_secret_objects", [])
}

module "app-helm-chart" {
  source                  = "./application"
  namespace               = local.namespace
  chart_name              = lower(var.instance_name)
  values                  = var.instance
  annotations             = local.annotations
  registry_secret_objects = length(local.from_artifactories) > 0 ? local.from_artifactories : local.from_kubernetes_cluster
  labels                  = local.labels
  environment             = var.environment
  inputs                  = var.inputs
}
locals {
  spec_json           = var.instance.spec
  userspecified_rules = lookup(local.spec_json, "recording_rules", {})
  metadata            = lookup(var.instance, "metadata", {})
  name                = lookup(local.metadata, "name", var.instance_name)
  group_interval      = lookup(local.spec_json, "interval", "5m")
  group_name          = lookup(local.spec_json, "group_name", "${var.instance_name}-recording-rules")
  all_metadata = {
    name      = lookup(local.metadata, "name", "${var.instance_name}-recording-rules")
    namespace = var.environment.namespace
    labels = merge(
      {
        recording_group_name = lookup(local.metadata, "name", "${var.instance_name}-recording-rules")
        role                 = "recording-rules"
      }, lookup(var.instance.metadata, "labels", {})
    )
    annotations = merge(
      {
        owner = "facets"

      }, lookup(var.instance.metadata, "annotations", {})
    )
  }
  # All recording rules
  all_recording_rules = [
    for rule_name, rule_object in local.userspecified_rules : {
      record = rule_name
      expr   = rule_object.expr
      labels = merge(
        {
          "resourceType"  = "prometheus-recording-rule"
          "resourceName"  = local.name
          "resource_type" = "prometheus-recording-rule"
          "resource_name" = local.name

        }, lookup(rule_object, "labels", {})
      )
    } if !lookup(rule_object, "disabled", false)
  ]
  # Manifest for the actual PrometheusRule resource
  recording_manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata   = local.all_metadata
    spec = {
      groups = [
        {
          name     = local.group_name
          interval = local.group_interval
          rules    = local.all_recording_rules

        }
      ]
    }
  }
  # Manifest to be used after yamlencode for parsing
  recording_manifest_yaml = yamlencode(local.recording_manifest)
  # Manifest clubed with anyResources object for rendering
  helm_values = {
    anyResources = {
      facets_recording = local.recording_manifest_yaml
    }
  }
  helm_values_yaml = yamlencode(local.helm_values)
}
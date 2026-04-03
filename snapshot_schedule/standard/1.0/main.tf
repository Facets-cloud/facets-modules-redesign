locals {
  spec = var.instance.spec
  name = lookup(local.spec, "name", module.name.name)
  retention_policy = lookup(local.spec, "retention_policy", {})
  namespace = lookup(local.spec, "namespace", "default")
  resource_name = lookup(local.spec, "resource_name", module.name.name)
  resource_type = lookup(local.spec, "resource_type", "snapshot_schedule")
  reserved_tags = {
    tagSpecification_1 = "resource_type=${local.resource_type}"
    tagSpecification_2 = "resource_name=${local.resource_name}"
    tagSpecification_3 = "snapshot_name=${local.name}"
  }
  user_tag_specifications    = (lookup(local.spec, "snapshot_tags", {}))
  reserved_tag_count = length(keys(local.reserved_tags))
  user_tags_flat = {
    for idx, k in tolist(keys(local.user_tag_specifications)) :
    "tagSpecification_${local.reserved_tag_count + idx + 1}" => "${k}=${local.user_tag_specifications[k]}"
  }
  final_tags = merge(local.reserved_tags, local.user_tags_flat)
  parameters = local.final_tags
  label_resource_type = {
    resource_type = local.resource_type
  }
  label_instance_name = {
    instance_name = local.resource_name
    resource_type = local.resource_type
  }
  custom_labels = lookup(local.spec, "labels", {})
  default_labels = {
    resource_name = local.name
    resource_type = "snapshot_schedule"
  }
  all_labels = merge(local.default_labels, local.custom_labels)
  annotations = lookup(local.spec, "annotations", {})
  driver = lookup(local.spec, "driver", "")
  additional_claim_selector_labels = lookup(local.spec, "additional_claim_selector_labels", {})

  kubernetes_details_input = lookup(var.inputs, "kubernetes_details", {})
  kubernetes_details_attrs = lookup(local.kubernetes_details_input, "attributes", {})
  cloud_provider           = lookup(local.kubernetes_details_attrs, "cloud_provider", "")
  snapshot_scheduler = lookup(var.inputs, "snapshot_scheduler", {})
  snapshot_scheduler_attrs = lookup(local.snapshot_scheduler, "attributes", {})



  # Determine driver based on cloud provider or use explicit override
  snapshot_driver = lookup(local.spec, "driver", "") != "" ? lookup(local.spec, "driver", "") : (
    local.cloud_provider == "AWS" ? "ebs.csi.aws.com" :
    local.cloud_provider == "GCP" ? "pd.csi.storage.gke.io" :
    "disk.csi.azure.com"
  )

}


module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  is_k8s          = false
  globally_unique = true
  resource_name   = var.instance_name
  resource_type   = "snapshot_schedule"
  limit           = 60
  environment     = var.environment
}




module "volume_snapshot_class" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = local.name
  namespace       = local.namespace
  advanced_config = {}

  data = {
    apiVersion = "snapshot.storage.k8s.io/v1"
    kind       = "VolumeSnapshotClass"
    metadata = {
      name        = local.name
      labels      = local.all_labels
      annotations = local.annotations
    }
    driver         = local.snapshot_driver
    deletionPolicy = lookup(local.spec, "deletionPolicy", "Delete")
    parameters     = local.parameters
  }
}

module "snapshot_schedule" {
  depends_on = [module.volume_snapshot_class]

  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = local.name
  namespace       = local.namespace
  advanced_config = {}

  data = {
    apiVersion = "snapscheduler.backube/v1"
    kind       = "SnapshotSchedule"
    metadata = {
      name      = local.name
      namespace = local.namespace
    }
    spec = {
      claimSelector = {
        matchLabels = merge(
          local.resource_name == null || local.resource_name == "" ? local.label_resource_type : local.label_instance_name,
          local.additional_claim_selector_labels
        )
      }
      retention = {
        expires  = lookup(local.retention_policy, "expires", "168h")
        maxCount = lookup(local.retention_policy, "max_count", 10)
      }
      schedule = lookup(local.spec, "schedule", "*/30 * * * *")
      snapshotTemplate = {
        labels            = lookup(local.spec, "snapshot_template_labels", {})
        snapshotClassName = local.name
      }
    }
  }
}

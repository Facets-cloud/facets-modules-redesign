locals {
  project_id = coalesce(
    lookup(var.inputs.network.attributes, "project_id", ""),
    lookup(var.inputs.cloud_account.attributes, "project_id", "")
  )
  region  = lookup(var.inputs.network.attributes, "region", "")
  network = lookup(var.inputs.network.attributes, "vpc_self_link", "")
  private_subnet = length(lookup(var.inputs.network.attributes, "private_subnet_ids", [])) > 0 ? (
    lookup(var.inputs.network.attributes, "private_subnet_ids", [])[0]
  ) : ""

  name_sanitized = lower(replace("${var.instance_name}-${var.environment.unique_name}", "/[^a-zA-Z0-9-]/", "-"))
  policy_name    = substr(trim(local.name_sanitized, "-"), 0, 63)

  labels = merge(
    var.environment.cloud_tags,
    lookup(var.instance.spec, "labels", {}),
    {
      managed-by    = "facets"
      instance-name = var.instance_name
      environment   = var.environment.name
      intent        = "gcp-service-connection-policy"
    }
  )
}

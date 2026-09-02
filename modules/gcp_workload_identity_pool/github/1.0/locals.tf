locals {
  project_id   = var.inputs.project.attributes.project_id
  project_num  = var.inputs.project.attributes.project_number
  pool_id      = lookup(var.instance.spec, "workload_identity_pool_id", "github")
  provider_id  = lookup(var.instance.spec, "provider_id", "github-oidc")
  repositories = lookup(var.instance.spec, "repositories", [])

  explicit_attribute_condition = try(trimspace(var.instance.spec.attribute_condition), "")
  attribute_condition          = local.explicit_attribute_condition != "" ? local.explicit_attribute_condition : "assertion.repository_owner == \"${var.instance.spec.github_org}\""

  repository_bindings_by_id = {
    for repo in local.repositories : repo => {
      member = "principalSet://iam.googleapis.com/projects/${local.project_num}/locations/global/workloadIdentityPools/${local.pool_id}/attribute.repository/${repo}"
    }
  }

  provider_resource_name = "${google_iam_workload_identity_pool.this.name}/providers/${local.provider_id}"
}

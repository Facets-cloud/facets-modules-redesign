locals {
  output_interfaces = {}
  output_attributes = {
    pool_name              = google_iam_workload_identity_pool.this.name
    pool_id                = google_iam_workload_identity_pool.this.workload_identity_pool_id
    provider_id            = local.provider_id
    provider_resource_name = local.provider_resource_name
  }
}

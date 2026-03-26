locals {
  output_attributes = {
    container_id   = ovh_cloud_project_storage.container.id
    container_name = ovh_cloud_project_storage.container.name
    region         = ovh_cloud_project_storage.container.region
    s3_endpoint    = local.s3_endpoint
    container_url  = local.container_url
    access_key     = local.access_key
    secret_key     = local.secret_key
    secrets        = ["access_key", "secret_key"]
  }
  output_interfaces = {}
}

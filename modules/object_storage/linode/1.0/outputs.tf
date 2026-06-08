locals {
  output_attributes = {
    bucket_id   = linode_object_storage_bucket.bucket.id
    bucket_name = linode_object_storage_bucket.bucket.label
    region      = var.instance.spec.region
    s3_endpoint = linode_object_storage_bucket.bucket.hostname
    bucket_url  = "https://${linode_object_storage_bucket.bucket.hostname}"
    access_key  = linode_object_storage_key.key.access_key
    secret_key  = linode_object_storage_key.key.secret_key
    secrets     = ["access_key", "secret_key"]
  }

  output_interfaces = {}
}

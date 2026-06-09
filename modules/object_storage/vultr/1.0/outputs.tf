locals {
  output_attributes = {
    object_storage_id = tostring(vultr_object_storage.store.id)
    label             = vultr_object_storage.store.label
    region            = vultr_object_storage.store.region
    cluster_id        = tostring(vultr_object_storage.store.cluster_id)
    s3_endpoint       = vultr_object_storage.store.s3_hostname
    s3_url            = "https://${vultr_object_storage.store.s3_hostname}"
    access_key        = vultr_object_storage.store.s3_access_key
    secret_key        = vultr_object_storage.store.s3_secret_key
    secrets           = ["access_key", "secret_key"]
  }

  output_interfaces = {}
}

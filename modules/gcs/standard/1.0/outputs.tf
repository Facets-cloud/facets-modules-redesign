locals {
  output_attributes = {
    bucket_name   = google_storage_bucket.this.name
    bucket_url    = google_storage_bucket.this.url
    self_link     = google_storage_bucket.this.self_link
    bucket_id     = google_storage_bucket.this.id
    location      = google_storage_bucket.this.location
    storage_class = google_storage_bucket.this.storage_class
    project_id    = google_storage_bucket.this.project
    labels        = google_storage_bucket.this.labels
  }

  output_interfaces = {}
}

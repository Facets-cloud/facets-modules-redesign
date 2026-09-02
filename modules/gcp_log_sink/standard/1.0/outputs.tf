locals {
  output_interfaces = {}
  output_attributes = {
    bucket_name      = google_storage_bucket.audit.name
    bucket_url       = google_storage_bucket.audit.url
    sink_name        = google_logging_folder_sink.this.name
    writer_identity  = google_logging_folder_sink.this.writer_identity
    retention_days   = local.retention_days
    retention_locked = local.retention_locked
  }
}

# ╔═══════════════════════════════════════════════════════════╗
# ║ Output contract: @facets/bucket                          ║
# ║ Keys managed by CLI — fill in the values only             ║
# ║ Do not add or remove keys. Do not rename.                 ║
# ║                                                           ║
# ║ View schema: raptor get output-type @facets/bucket       ║
# ╚═══════════════════════════════════════════════════════════╝

locals {
  gcs_bucket_name   = google_storage_bucket.this.name
  gcs_resource_name = "projects/_/buckets/${google_storage_bucket.this.name}"

  output_attributes = {
    bucket_name   = local.gcs_bucket_name
    resource_name = local.gcs_resource_name
    region        = local.location
    read_grant    = "roles/storage.objectViewer"
    write_grant   = "roles/storage.objectAdmin"
  }
  output_interfaces = {
    default = {
      name = local.gcs_bucket_name
    }
  }
}

# --- END MANAGED SECTION --- Add your custom outputs below ---

# Add your custom Terraform outputs below this line.

locals {
  output_interfaces = {}
  output_attributes = {
    folder_id   = google_folder.this.folder_id
    folder_name = google_folder.this.name
    parent      = google_folder.this.parent
  }
}

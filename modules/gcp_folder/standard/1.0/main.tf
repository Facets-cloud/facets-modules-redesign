terraform {
  required_version = ">= 1.0"
}

resource "google_folder" "this" {
  display_name        = var.instance.spec.display_name
  parent              = local.parent
  deletion_protection = local.deletion_protection
}

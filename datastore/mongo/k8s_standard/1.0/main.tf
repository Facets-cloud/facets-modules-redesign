# main.tf - MongoDB Kubernetes Operator Implementation

# Generate random password
resource "random_password" "mongodb_password" {
  length  = 16
  special = false
}

# Password secret manifest (defined after random_password to avoid circular dependency)
locals {
  password_secret_manifest = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "${var.instance_name}-admin-password"
      namespace = local.namespace
    }
    type = "Opaque"
    data = {
      password = base64encode(random_password.mongodb_password.result)
    }
  }
}

# Create password secret
module "mongodb_password_secret" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${var.instance_name}-admin-password"
  release_name    = "${var.instance_name}-secret"
  namespace       = local.namespace
  data            = local.password_secret_manifest
  advanced_config = {}
}

# Deploy MongoDB using any-k8s-resource
module "mongodb" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = var.instance_name
  release_name    = var.instance_name
  namespace       = local.namespace
  data            = local.mongodb_manifest
  advanced_config = {}

  depends_on = [module.mongodb_password_secret]
}

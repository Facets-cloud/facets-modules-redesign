# main.tf - MongoDB Kubernetes Operator Implementation

# Generate random password
resource "random_password" "mongodb_password" {
  length  = 16
  special = false
}

# Service account manifest for MongoDB operator
locals {
  service_account_manifest = {
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name      = "mongodb-kubernetes-appdb"
      namespace = local.namespace
    }
  }

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

# Create service account
module "mongodb_service_account" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "mongodb-kubernetes-appdb"
  release_name    = "${var.instance_name}-sa"
  namespace       = local.namespace
  data            = local.service_account_manifest
  advanced_config = {}
}

# Create password secret
module "mongodb_password_secret" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${var.instance_name}-admin-password"
  release_name    = "${var.instance_name}-secret"
  namespace       = local.namespace
  data            = local.password_secret_manifest
  advanced_config = {}

  depends_on = [module.mongodb_service_account]
}

# Deploy MongoDB using any-k8s-resource
module "mongodb" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = var.instance_name
  release_name    = var.instance_name
  namespace       = local.namespace
  data            = local.mongodb_manifest
  advanced_config = {}

  depends_on = [module.mongodb_password_secret, module.mongodb_service_account]
}

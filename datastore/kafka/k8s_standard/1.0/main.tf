# main.tf - Strimzi Kafka Cluster Implementation

# Generate admin password
resource "random_password" "kafka_admin_password" {
  length  = 16
  special = false
}

# Password secret manifest (defined after random_password to avoid circular dependency)
locals {
  password_secret_manifest = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "${var.instance_name}-${local.admin_username}-password"
      namespace = local.namespace
    }
    type = "Opaque"
    data = {
      password = base64encode(random_password.kafka_admin_password.result)
    }
  }
}

# Deploy password secret first
module "kafka_admin_password_secret" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${var.instance_name}-${local.admin_username}-password"
  release_name    = "${var.instance_name}-admin-secret"
  namespace       = local.namespace
  data            = local.password_secret_manifest
  advanced_config = {}
}

# Deploy KafkaNodePool using any-k8s-resource
module "kafka_node_pool" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${var.instance_name}-${local.node_pool_name}"
  release_name    = "${var.instance_name}-nodepool"
  namespace       = local.namespace
  data            = local.kafka_node_pool_manifest
  advanced_config = {}
}

# Deploy Kafka using any-k8s-resource
module "kafka" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = var.instance_name
  release_name    = var.instance_name
  namespace       = local.namespace
  data            = local.kafka_manifest
  advanced_config = {}

  depends_on = [module.kafka_node_pool]
}

# Deploy KafkaUser for admin
module "kafka_admin_user" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${var.instance_name}-${local.admin_username}"
  release_name    = "${var.instance_name}-admin-user"
  namespace       = local.namespace
  data            = local.kafka_user_manifest
  advanced_config = {}

  depends_on = [module.kafka_admin_password_secret, module.kafka]
}

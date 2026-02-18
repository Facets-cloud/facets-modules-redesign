# Generate admin password
resource "random_password" "kafka_admin_password" {
  length  = 16
  special = false
}

# Name module for kafka main resource
module "kafka_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 53
  resource_name   = var.instance_name
  resource_type   = "kafka"
  is_k8s          = true
  globally_unique = false
}

# Name module for kafka node pool resource
module "pool_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 53
  resource_name   = var.instance_name
  resource_type   = "kafka-pool"
  is_k8s          = true
  globally_unique = false
}

# Name module for kafka admin password secret
module "secret_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 53
  resource_name   = var.instance_name
  resource_type   = "kafka-secret"
  is_k8s          = true
  globally_unique = false
}

# Name module for kafka admin user
module "user_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 53
  resource_name   = var.instance_name
  resource_type   = "kafka-user"
  is_k8s          = true
  globally_unique = false
}

# Password secret manifest
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
  source       = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name         = "${var.instance_name}-${local.admin_username}-password"
  release_name = module.secret_name.name
  namespace    = local.namespace
  data         = local.password_secret_manifest

  advanced_config = {}
}

# Deploy KafkaNodePool using any-k8s-resource
module "kafka_node_pool" {
  source       = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name         = "${var.instance_name}-${local.node_pool_name}"
  release_name = module.pool_name.name
  namespace    = local.namespace
  data         = local.kafka_node_pool_manifest

  advanced_config = {}
}

# Deploy Kafka using any-k8s-resource
module "kafka" {
  source       = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name         = var.instance_name
  release_name = module.kafka_name.name
  namespace    = local.namespace
  data         = local.kafka_manifest

  advanced_config = {}

  depends_on = [module.kafka_node_pool]
}

# Deploy KafkaUser for admin
module "kafka_admin_user" {
  source       = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name         = "${var.instance_name}-${local.admin_username}"
  release_name = module.user_name.name
  namespace    = local.namespace
  data         = local.kafka_user_manifest

  advanced_config = {}

  depends_on = [module.kafka_admin_password_secret, module.kafka]
}

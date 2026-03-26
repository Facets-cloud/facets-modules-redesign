# OVH Cloud Project Managed MongoDB Database Module
# Creates a managed MongoDB database with private network connectivity
# Database is only accessible from within the private network

locals {
  # Get region from network input and strip any numeric suffix
  # Network module provides regions like "BHS5" but database API expects "BHS"
  region_raw = var.inputs.network.attributes.region
  region     = replace(local.region_raw, "/[0-9]+$/", "")

  # Database name automatically computed from environment and instance name
  database_name = "${var.environment.unique_name}-${var.instance_name}"

  # Dynamic node configuration based on nodes_count
  nodes = [
    for i in range(var.instance.spec.sizing.nodes_count) : {
      region     = local.region
      network_id = var.inputs.network.attributes.openstack_network_id
      subnet_id  = var.inputs.network.attributes.db_subnet_id
    }
  ]
}

# Create the managed MongoDB database
resource "ovh_cloud_project_database" "mongodb" {
  service_name = var.inputs.ovh_provider.attributes.project_id
  description  = "Private MongoDB database: ${local.database_name}"
  engine       = "mongodb"
  version      = var.instance.spec.version_config.version
  plan         = var.instance.spec.sizing.plan
  flavor       = var.instance.spec.sizing.flavor

  # Storage configuration
  disk_size = var.instance.spec.sizing.disk_size

  # Network and node configuration - Private network only
  dynamic "nodes" {
    for_each = local.nodes
    content {
      region     = nodes.value.region
      network_id = nodes.value.network_id
      subnet_id  = nodes.value.subnet_id
    }
  }

  # IP restrictions - Only allow access from the private network CIDR
  ip_restrictions {
    description = "Private network access only"
    ip          = var.inputs.network.attributes.network_cidr
  }

  # Lifecycle management - prevent accidental deletion of stateful resources
  lifecycle {
    prevent_destroy = true
  }

  timeouts {
    create = "30m"
    update = "45m"
    delete = "20m"
  }
}

# Create MongoDB user for application access
resource "ovh_cloud_project_database_mongodb_user" "app_user" {
  service_name = var.inputs.ovh_provider.attributes.project_id
  cluster_id   = ovh_cloud_project_database.mongodb.id
  name         = "appuser"
  roles        = ["readWriteAnyDatabase@admin", "dbAdminAnyDatabase@admin"]

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
}

# Wait for database to be ready
resource "null_resource" "database_ready" {
  depends_on = [
    ovh_cloud_project_database.mongodb,
    ovh_cloud_project_database_mongodb_user.app_user
  ]

  provisioner "local-exec" {
    command = "echo 'Private MongoDB database ${local.database_name} is ready and accessible only from within the private network'"
  }
}

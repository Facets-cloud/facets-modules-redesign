# OVH Cloud Project Managed MySQL Database Module
# Creates a managed MySQL database with private network connectivity
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

# Create the managed MySQL database
resource "ovh_cloud_project_database" "mysql" {
  service_name = var.inputs.ovh_provider.attributes.project_id
  description  = "Private MySQL database: ${local.database_name}"
  engine       = "mysql"
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

  # Advanced configuration for MySQL
  advanced_configuration = {
    "mysql.sql_mode"                = "ANSI,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION,NO_ZERO_DATE,NO_ZERO_IN_DATE,STRICT_ALL_TABLES"
    "mysql.sql_require_primary_key" = "false"
    "mysql.log_output"              = "INSIGHTS"
    "mysql.long_query_time"         = "1"
    "mysql.slow_query_log"          = "true"
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

# Reset the avnadmin user password to get access to it
resource "ovh_cloud_project_database_user" "avnadmin" {
  service_name = var.inputs.ovh_provider.attributes.project_id
  engine       = "mysql"
  cluster_id   = ovh_cloud_project_database.mysql.id
  name         = "avnadmin"

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
}

# Wait for database to be ready
resource "null_resource" "database_ready" {
  depends_on = [
    ovh_cloud_project_database.mysql,
    ovh_cloud_project_database_user.avnadmin
  ]

  provisioner "local-exec" {
    command = "echo 'Private MySQL database ${local.database_name} is ready and accessible only from within the private network'"
  }
}

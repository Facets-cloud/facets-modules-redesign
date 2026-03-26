# OVH Cloud Project Managed Valkey Database Module
# Creates a managed Valkey (Redis-compatible) database with private network connectivity
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

# Create the managed Valkey database
resource "ovh_cloud_project_database" "valkey" {
  service_name = var.inputs.ovh_provider.attributes.project_id
  description  = "Private Valkey database: ${local.database_name}"
  engine       = "valkey"
  version      = var.instance.spec.version_config.version
  plan         = var.instance.spec.sizing.plan
  flavor       = var.instance.spec.sizing.flavor

  # Network and node configuration - Private network only
  dynamic "nodes" {
    for_each = local.nodes
    content {
      region     = nodes.value.region
      network_id = nodes.value.network_id
      subnet_id  = nodes.value.subnet_id
    }
  }

  # Advanced Valkey configuration
  advanced_configuration = {
    "valkey_maxmemory_policy"       = var.instance.spec.advanced_config.maxmemory_policy
    "valkey_timeout"                = var.instance.spec.advanced_config.timeout
    "valkey_notify_keyspace_events" = var.instance.spec.advanced_config.notify_keyspace_events
    "valkey_persistence"            = var.instance.spec.advanced_config.persistence

    # OVH default values - include these to prevent perpetual diff
    "valkey_active_expire_effort" = "1"
    "valkey_io_threads"           = "1"
    "valkey_lfu_decay_time"       = "1"
    "valkey_lfu_log_factor"       = "10"
    "valkey_ssl"                  = "false"
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

# Create a database user (application user)
resource "ovh_cloud_project_database_valkey_user" "app_user" {
  service_name = var.inputs.ovh_provider.attributes.project_id
  cluster_id   = ovh_cloud_project_database.valkey.id
  name         = "app_user"

  categories = ["+@all"]
  commands   = []
  keys       = ["*"]
  channels   = ["*"]

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
}

# Wait for database to be ready
resource "null_resource" "database_ready" {
  depends_on = [
    ovh_cloud_project_database.valkey,
    ovh_cloud_project_database_valkey_user.app_user
  ]

  provisioner "local-exec" {
    command = "echo 'Private Valkey database ${local.database_name} is ready and accessible only from within the private network'"
  }
}

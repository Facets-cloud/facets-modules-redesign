locals {
  # Import configuration with proper null handling
  import_account_name  = try(var.instance.spec.imports.account_name, null)
  import_database_name = try(var.instance.spec.imports.database_name, null)

  # Ensure names are within 44 character limit for Azure Cosmos DB
  # Format: instance-env-suffix (total must be <= 44 chars)
  # Random suffix is 6 chars, so we have 44 - 6 - 2(hyphens) = 36 chars for instance + env parts

  # Clean instance and environment names (lowercase, replace invalid chars)
  clean_instance = lower(replace(var.instance_name, "_", "-"))
  clean_env      = lower(replace(var.environment.unique_name, "_", "-"))

  # Calculate available space for instance and env parts
  available_space = 36                                                                           # 44 total - 6 (suffix) - 2 (hyphens)
  instance_max    = min(15, length(local.clean_instance))                                        # Cap instance at 15 chars
  env_max         = min(local.available_space - local.instance_max - 1, length(local.clean_env)) # Remaining space

  # Truncate parts ensuring they don't end with hyphens
  instance_part = regex("^(.+?)[-]*$", substr(local.clean_instance, 0, local.instance_max))[0]
  env_part      = regex("^(.+?)[-]*$", substr(local.clean_env, 0, local.env_max))[0]

  # Build name that won't exceed 44 chars and follows Azure naming rules
  account_name  = "${local.instance_part}-${local.env_part}-${random_string.suffix.result}"
  database_name = "db-${substr(local.instance_part, 0, 20)}-${random_string.suffix.result}"

  # Generate final database name for outputs
  final_database_name = local.import_database_name != null ? local.import_database_name : local.database_name

  # Get the actual account (either created or imported)
  cosmos_account = local.import_account_name != null ? data.azurerm_cosmosdb_account.existing[0] : azurerm_cosmosdb_account.mongodb[0]

  # Connection details
  cluster_endpoint = local.cosmos_account.endpoint
  cluster_port     = var.instance.spec.version_config.port

  # Master credentials for compatibility with @facets/mongo interface
  master_username = "cosmosadmin"
  master_password = local.cosmos_account.primary_key

  # Build connection strings compatible with DocumentDB format
  connection_string          = "mongodb://${local.master_username}:${local.master_password}@${local.cluster_endpoint}:${local.cluster_port}/${local.final_database_name}?ssl=true&retrywrites=false"
  readonly_connection_string = "mongodb://${local.master_username}:${local.cosmos_account.secondary_key}@${local.cluster_endpoint}:${local.cluster_port}/${local.final_database_name}?ssl=true&retrywrites=false"
}
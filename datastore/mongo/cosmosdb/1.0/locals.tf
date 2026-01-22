locals {
  # Import flag
  import_enabled = lookup(var.instance.spec, "imports", null) != null ? lookup(var.instance.spec.imports, "import_existing", false) : false

  # Import configuration - now expects full Azure resource IDs
  import_account_id  = local.import_enabled ? try(var.instance.spec.imports.account_name, null) : null
  import_database_id = local.import_enabled ? try(var.instance.spec.imports.database_name, null) : null

  # Extract account name from resource ID for use in Terraform configs
  # Format: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{name}
  import_account_name  = local.import_account_id != null ? element(split("/", local.import_account_id), length(split("/", local.import_account_id)) - 1) : null
  import_database_name = local.import_database_id != null ? element(split("/", local.import_database_id), length(split("/", local.import_database_id)) - 1) : null

  # Mode detection flags
  is_restore = try(var.instance.spec.restore_config.restore_from_backup, false) == true
  is_import  = local.import_enabled && local.import_account_id != null

  # Database should exist for both import and create modes (not restore)
  database_count = local.is_restore ? 0 : 1

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

  # Random suffix - only used when NOT importing
  random_suffix = local.is_import ? "" : random_string.suffix[0].result

  # Build name that won't exceed 44 chars and follows Azure naming rules
  # Use import names when importing, otherwise generate new names
  account_name  = local.is_import ? local.import_account_name : "${local.instance_part}-${local.env_part}-${local.random_suffix}"
  database_name = local.is_import && local.import_database_name != null ? local.import_database_name : "db-${substr(local.instance_part, 0, 20)}-${local.random_suffix}"

  # Generate final database name for outputs
  final_database_name = local.cosmos_database.name

  # Get the actual account (either created, imported, or restored)
  # When importing but the account is not yet in state, we need to handle this gracefully
  cosmos_account = (
    local.is_restore ? azurerm_cosmosdb_account.mongodb_restored[0] : azurerm_cosmosdb_account.mongodb[0]
  )

  # Get the actual database (either created, imported, or restored)
  cosmos_database = (
    local.is_restore ? azurerm_cosmosdb_mongo_database.main_restored[0] : azurerm_cosmosdb_mongo_database.main[0]
  )

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
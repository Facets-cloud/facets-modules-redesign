locals {
  location = lookup(var.instance.spec, "location", "asia-south1")

  service_agent_configs = {
    sqladmin = {
      service       = "sqladmin.googleapis.com"
      email_pattern = "service-%s@gcp-sa-cloud-sql.iam.gserviceaccount.com"
      mode          = "service_identity"
    }
    storage = {
      service       = "storage.googleapis.com"
      email_pattern = "service-%s@gs-project-accounts.iam.gserviceaccount.com"
      mode          = "storage_project_service_account"
    }
    pubsub = {
      service       = "pubsub.googleapis.com"
      email_pattern = "service-%s@gcp-sa-pubsub.iam.gserviceaccount.com"
      mode          = "service_identity"
    }
    secretmanager = {
      service       = "secretmanager.googleapis.com"
      email_pattern = "service-%s@gcp-sa-secretmanager.iam.gserviceaccount.com"
      mode          = "service_identity"
    }
    redis = {
      service       = "redis.googleapis.com"
      email_pattern = "service-%s@cloud-redis.iam.gserviceaccount.com"
      mode          = "service_identity"
    }
    compute = {
      service       = "compute.googleapis.com"
      email_pattern = "service-%s@compute-system.iam.gserviceaccount.com"
      mode          = "service_identity"
    }
    container = {
      service       = "container.googleapis.com"
      email_pattern = "service-%s@container-engine-robot.iam.gserviceaccount.com"
      mode          = "service_identity"
    }
    artifactregistry = {
      service       = "artifactregistry.googleapis.com"
      email_pattern = "service-%s@gcp-sa-artifactregistry.iam.gserviceaccount.com"
      mode          = "service_identity"
    }
  }

  keys_by_name = {
    for key in lookup(var.instance.spec, "keys", []) : key.name => key
  }

  configured_service_agents = distinct(flatten([
    for key in lookup(var.instance.spec, "keys", []) : lookup(key, "service_agents", [])
  ]))

  unknown_service_agents = sort([
    for service_agent in local.configured_service_agents : service_agent
    if !contains(keys(local.service_agent_configs), service_agent)
  ])

  input_grantee_project_number    = coalesce(try(var.inputs.grantee_project.attributes.project_number, null), "")
  fallback_grantee_project_number = local.input_grantee_project_number != "" ? local.input_grantee_project_number : var.inputs.project.attributes.project_number

  key_grants = flatten([
    for key in lookup(var.instance.spec, "keys", []) : [
      for project_number in length(lookup(key, "grant_project_numbers", [])) > 0 ? lookup(key, "grant_project_numbers", []) : [local.fallback_grantee_project_number] : [
        for service_agent in lookup(key, "service_agents", []) : {
          key_name       = key.name
          project_number = project_number
          service_agent  = service_agent
        }
      ]
    ]
  ])

  key_grants_by_id = {
    for grant in local.key_grants : "${grant.key_name}/${grant.project_number}/${grant.service_agent}" => grant
    if contains(keys(local.service_agent_configs), grant.service_agent)
  }

  service_identity_grants_by_id = {
    for grant in local.key_grants : "${grant.project_number}/${grant.service_agent}" => grant
    if contains(keys(local.service_agent_configs), grant.service_agent) && local.service_agent_configs[grant.service_agent].mode == "service_identity"
  }
}

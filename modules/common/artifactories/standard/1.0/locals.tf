# First locals block - values needed for the external data source
locals {
  spec          = lookup(var.instance, "spec", {})
  metadata      = lookup(var.instance, "metadata", {})
  artifactories = lookup(local.spec, "artifactories", {})
  include_all   = lookup(local.spec, "include_all", length(local.artifactories) > 0 ? false : true)

  # Get artifactory names list for filtering
  artifactory_names = jsonencode([for key, value in local.artifactories : value["name"]])
}

# Fetch artifactories from deployment context via external script
data "external" "artifactory_fetcher" {
  program = [
    "python3",
    "/sources/primary/capillary-cloud-tf/tfmain/scripts/artifactory-fetch-secret/artifactory-fetcher.py",
    local.include_all,
    local.artifactory_names
  ]
}

# Second locals block - values that depend on the external data source
locals {
  name               = lookup(local.metadata, "name", var.instance_name)
  namespace          = lookup(local.metadata, "namespace", lookup(var.environment, "namespace", "default"))
  kubernetes_details = var.inputs.kubernetes_details.attributes

  # Node pool configuration
  kubernetes_node_pool_details = lookup(var.inputs, "kubernetes_node_pool_details", {})
  node_pool_labels             = lookup(local.kubernetes_node_pool_details, "node_selector", {})
  node_pool_taints_raw         = lookup(local.kubernetes_node_pool_details, "taints", {})

  # Transform taints from object format to Kubernetes toleration format
  node_pool_tolerations = [
    for taint_name, taint_config in local.node_pool_taints_raw : {
      key      = taint_config.key
      operator = "Equal"
      value    = taint_config.value
      effect   = taint_config.effect
    }
  ]

  # Combine arch selector with node pool labels
  node_selector = merge(
    {
      "kubernetes.io/arch" = "amd64"
    },
    local.node_pool_labels
  )

  # Parse artifactories from external script output
  artifactories_ecr       = jsondecode(data.external.artifactory_fetcher.result["artifactories_ecr"])
  artifactories_dockerhub = jsondecode(data.external.artifactory_fetcher.result["artifactories_dockerhub"])

  ecr_secret_objects = {
    for artifactory in local.artifactories_ecr : artifactory["name"] => [{ name : "${local.name}-${artifactory["name"]}" }]
  }

  artifact_uri      = [for artifact in local.artifactories_dockerhub : artifact["uri"]]
  has_duplicate_uri = length(distinct(local.artifact_uri)) == length(local.artifact_uri) ? false : true
  secret_metadata = !local.has_duplicate_uri ? {
    "${local.name}" = {
      name = local.name
      dockerconfigjson = jsonencode({
        auths = {
          for key, value in local.artifactories_dockerhub :
          value.uri => {
            username = value.username
            password = value.password
            email    = lookup(value, "email", "no@email.com")
            auth     = base64encode("${value.username}:${value.password}")
          }
        }
      })
    }
    } : { for key, value in local.artifactories_dockerhub : "${local.name}-${key}" => {
      name = "${local.name}-${key}"
      dockerconfigjson = jsonencode({
        auths = {
          "${value.uri}" = {
            username = value.username
            password = value.password
            email    = lookup(value, "email", "no@email.com")
            auth     = base64encode("${value.username}:${value.password}")
          }
        }
      })
  } }
  dockerhub_secret_objects = {
    for dockerhub_artifactory in local.artifactories_dockerhub : dockerhub_artifactory["name"] => [{ name : !local.has_duplicate_uri ? local.name : "${local.name}-${dockerhub_artifactory["name"]}" }]
  }

  registry_secret_objects = merge(local.ecr_secret_objects, local.dockerhub_secret_objects)
  registry_secrets_list   = flatten([for k, v in merge(local.registry_secret_objects) : v])

  labels = merge(lookup(local.metadata, "labels", {}), { "secret-copier" = "yes" })

  labels_ecr = join(",", [for k, v in local.labels : "${k}=${v}"])
}

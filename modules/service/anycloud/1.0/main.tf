locals {
  spec = lookup(var.instance, "spec", {})
  # spec.namespace wins when set; otherwise fall back to the environment namespace. A pod can only
  # mount a ConfigMap or Secret from its OWN namespace, so this lets a service sit beside the
  # config_map/anycloud resources it mounts.
  namespace = trimspace(try(local.spec.namespace, "")) != "" ? trimspace(local.spec.namespace) : var.environment.namespace
  # KSA annotations for same-cloud identity. On AWS with IRSA enabled the ServiceAccount is
  # annotated with the created role (eks.amazonaws.com/role-arn). GKE Workload Identity grants roles
  # to the KSA principal directly (gcp.tf), so it needs no annotation.
  annotations = merge(
    local.irsa_enabled ? { "eks.amazonaws.com/role-arn" = local.irsa_role_arn } : {},
    # Force a rolling update on every release. deployment_id is unique per deploy, so stamping it
    # onto the pod template makes the template hash change even when the image tag is unchanged
    # (e.g. :latest re-pushed by CI). An empty id leaves it out.
    trimspace(var.environment.deployment_id) != "" ? { "buildId" = var.environment.deployment_id } : {}
  )
  labels        = {}
  resource_type = "service"
  resource_name = var.instance_name

  # Image pull secrets from the optional artifactories input
  image_pull_secrets = try(var.inputs.artifactories.attributes.registry_secrets_list, [])

  # Node pool scheduling from the optional kubernetes_node_pool_details input (@facets/kubernetes_nodepool).
  # Guarded/no-op when unwired: try() short-circuits the whole missing path.
  # node_selector -> pod nodeSelector; taints -> {key,value,effect,operator:"Equal"} tolerations.
  # application/2.0 reads taint.key / taint.value / taint.effect, so it needs OBJECTS — passing the
  # encoded "key=value:effect" strings makes it fail with "Can't access attributes on a
  # primitive-typed value (string)". Hand it local.np_tolerations directly.
  np_node_selector = try(coalesce(var.inputs.kubernetes_node_pool_details.attributes.node_selector, {}), {})
  np_taints        = try(coalesce(var.inputs.kubernetes_node_pool_details.attributes.taints, []), [])
  np_tolerations = [for t in local.np_taints : {
    key      = try(t.key, null)
    value    = try(t.value, null)
    effect   = try(t.effect, null)
    operator = "Equal"
  }]
  modified_inputs = merge(var.inputs, {
    kubernetes_node_pool_details = {
      taints        = local.np_tolerations
      node_selector = local.np_node_selector
    }
  })

  # Pod distribution / topology spread (from spec, no external input)
  enable_host_anti_affinity = lookup(local.spec, "enable_host_anti_affinity", false)
  pod_distribution_enabled  = lookup(local.spec, "pod_distribution_enabled", false)
  pod_distribution_spec     = lookup(local.spec, "pod_distribution", {})
  pod_distribution_array = [
    for key, config in local.pod_distribution_spec : {
      topology_key         = config.topology_key
      when_unsatisfiable   = config.when_unsatisfiable
      max_skew             = config.max_skew
      node_taints_policy   = lookup(config, "node_taints_policy", null)
      node_affinity_policy = lookup(config, "node_affinity_policy", null)
    }
  ]
  pod_distribution = local.pod_distribution_enabled ? (
    length(local.pod_distribution_spec) > 0 ? local.pod_distribution_array : (
      local.enable_host_anti_affinity ? [{
        topology_key       = "kubernetes.io/hostname"
        when_unsatisfiable = "DoNotSchedule"
        max_skew           = 1
      }] : []
    )
  ) : []

  # --- cloud_permissions: keyless same-cloud pod IAM ---------------------------------------------
  # Branch on the linked cloud_account. Chart SA = "<lower(instance)>-sa".
  cloud_provider    = try(var.inputs.cloud_account.attributes.cloud_provider, null)
  is_aws            = local.cloud_provider == "AWS"
  is_gcp            = local.cloud_provider == "GCP"
  cloud_permissions = lookup(local.spec, "cloud_permissions", {})
  cp_aws            = try(local.cloud_permissions.aws, {})
  cp_gcp            = try(local.cloud_permissions.gcp, {})
  ksa_name          = "${lower(var.instance_name)}-sa"

  # EKS IRSA — role in the workload account, trust = the cluster's own OIDC provider (aws.tf).
  # The count gate is a plan-known spec toggle, never a wired input's computed value.
  irsa_enabled      = local.is_aws && try(local.cp_aws.enable_irsa, false)
  iam_policy_arns   = [for k, v in try(local.cp_aws.iam_policies, {}) : v.arn]
  aws_inline_policy = trimspace(try(local.cp_aws.inline_policy_json, ""))
  # interfaces.aws.* EXIST and are null on a GCP cluster (inactive cloud is null-keyed). try() catches
  # errors, not null values, so trimspace() goes inside try() to turn both cases into "".
  eks_oidc_arn      = try(trimspace(var.inputs.kubernetes_cluster.interfaces.aws.oidc_provider_arn), "")
  eks_oidc_provider = try(trimspace(var.inputs.kubernetes_cluster.interfaces.aws.oidc_provider), "")
  irsa_role_arn     = try(aws_iam_role.irsa[0].arn, "")

  # GKE Workload Identity — grant roles to the KSA's WI principal (gcp.tf). Explicit toggle (the GKE
  # equivalent of enable_irsa), so adding roles alone doesn't silently activate it.
  wi_roles    = try(local.cp_gcp.roles, {})
  wi_enabled  = local.is_gcp && try(local.cp_gcp.enable_wi, false)
  gcp_project = try(var.inputs.cloud_account.attributes.gcp.project_id, null)
  # Gate on the cloud, do not try(): locals evaluate eagerly, and on GCP a null project must fail
  # loudly instead of handing the IAM resources an empty member.
  wi_member = !local.is_gcp ? "" : "serviceAccount:${local.gcp_project}.svc.id.goog[${local.namespace}/${local.ksa_name}]"

  # Inject computed values into the application chart values (VPA disabled — no vpa input)
  base_app_values = lookup(lookup(lookup(lookup(var.instance, "advanced", {}), "common", {}), "app_chart", {}), "values", {})

  instance_with_config = merge(var.instance, {
    advanced = merge(lookup(var.instance, "advanced", {}), {
      common = merge(lookup(lookup(var.instance, "advanced", {}), "common", {}), {
        app_chart = merge(lookup(lookup(lookup(var.instance, "advanced", {}), "common", {}), "app_chart", {}), {
          values = merge(
            local.base_app_values,
            {
              enable_vpa               = false
              pod_distribution_enabled = local.pod_distribution_enabled
              pod_distribution         = local.pod_distribution
              image_pull_secrets       = local.image_pull_secrets
            }
          )
        })
      })
    })
  })
}

module "sr-name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  is_k8s          = false
  globally_unique = true
  resource_name   = local.resource_name
  resource_type   = local.resource_type
  limit           = 60
  environment     = var.environment
}

module "app-helm-chart" {
  source         = "github.com/Facets-cloud/facets-utility-modules//application/2.0"
  namespace      = local.namespace
  chart_name     = lower(var.instance_name)
  values         = local.instance_with_config
  annotations    = local.annotations
  labels         = local.labels
  environment    = var.environment
  inputs         = local.modified_inputs
  vpa_release_id = ""
}

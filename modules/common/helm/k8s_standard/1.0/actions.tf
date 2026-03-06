resource "facets_tekton_action_kubernetes" "helm_history" {
  count                = local.enable_actions
  name                 = "helm-history"
  description          = "Retrieves helm release history for the deployed chart"
  facets_resource_name = var.instance_name
  facets_environment   = var.environment.unique_name
  facets_resource      = var.instance

  steps = [
    {
      name   = "get-helm-history"
      image  = "alpine/helm:latest"
      script = <<-EOT
        #!/bin/bash
        echo "Fetching helm history for helm release: ${helm_release.external_helm_charts.name}"
        helm history ${helm_release.external_helm_charts.name} -n ${helm_release.external_helm_charts.namespace}
      EOT
    }
  ]
}

resource "facets_tekton_action_kubernetes" "helm_rollback" {
  count                = local.enable_actions
  name                 = "helm-rollback"
  description          = "Rolls back helm release to a specified revision"
  facets_resource_name = var.instance_name
  facets_environment   = var.environment.unique_name
  facets_resource      = var.instance

  params = [
    {
      name = "revision"
      type = "string"
    }
  ]

  steps = [
    {
      name   = "rollback-helm-release"
      image  = "alpine/helm:latest"
      script = <<-EOT
        #!/bin/bash
        REVISION="$(params.revision)"

        if [ -z "$REVISION" ]; then
          echo "error: Revision number is required"
          exit 1
        fi

        echo "Rolling back release ${helm_release.external_helm_charts.name} to revision $REVISION"
        helm rollback ${helm_release.external_helm_charts.name} $REVISION -n ${helm_release.external_helm_charts.namespace}

        if [ $? -eq 0 ]; then
          echo "Rollback successful"
          echo "Current release status:"
          helm status ${helm_release.external_helm_charts.name} -n ${helm_release.external_helm_charts.namespace}
        else
          echo "Rollback failed"
          exit 1
        fi
      EOT
    }
  ]
}

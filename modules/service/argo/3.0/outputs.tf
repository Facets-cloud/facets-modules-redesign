# Output contract: @facets/service
#
# 2.x derived the Kubernetes service name by guessing: four hardcoded lookup
# patterns over the chart values (including a `gateway-consumer` special case),
# falling back to the release name. That coupled a general flavor to specific
# CoinSwitch charts and silently produced a wrong name for any chart outside
# those patterns.
#
# 3.0 does not guess. The Helm release name IS the stable, knowable identifier -
# it is what the module sets on the Application and what the shim matches on -
# so it is what gets published. A chart whose Service is named differently
# should say so through its own values.

locals {
  output_interfaces = {}

  # Exactly the attributes @facets/service declares (RULE-012) - the same
  # contract every other service flavor publishes, so downstream consumers stay
  # cloud- and flavor-agnostic. Argo-specific coordinates deliberately are NOT
  # published here; a consumer that needs them wants argo_service, not service.
  output_attributes = {
    namespace           = local.namespace
    resource_name       = local.service_name
    resource_type       = "service"
    service_name        = local.release_name
    selector_labels     = jsonencode({ "app.kubernetes.io/instance" = local.release_name })
    service_account_arn = try(google_service_account.wi[keys(local.wi_gcp_accounts)[0]].email, "")
  }
}

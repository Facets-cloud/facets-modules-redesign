# Output contract: @facets/service
#
# 2.x derived the Kubernetes service name by guessing: four hardcoded lookup
# patterns over the chart values (including a `gateway-consumer` special case),
# falling back to the release name. That coupled a general flavor to specific
# CoinSwitch charts and silently produced a wrong name for any chart outside
# those patterns.
#
# 3.0 does not guess, and does not substitute the release name either: the
# release name is what Argo is told to call the Helm release, not a promise about
# what the chart names its Service or how it labels its pods.

locals {
  output_interfaces = {}

  # Exactly the attributes @facets/service declares (RULE-012) - the same
  # contract every other service flavor publishes, so downstream consumers stay
  # cloud- and flavor-agnostic. Argo-specific coordinates deliberately are NOT
  # published here; a consumer that needs them wants argo_service, not service.
  #
  # service_name and selector_labels are published EMPTY on purpose. This module
  # hands a chart to ArgoCD and Argo renders it, so the Kubernetes objects the
  # chart produces - their names, their labels, whether a Service exists at all -
  # are not knowable here. Verified against the tested demo-app chart: its pods
  # carry `app=demo-app`, not `app.kubernetes.io/instance=demo-app`, and the
  # chart creates no Service whatsoever. Both former guesses were therefore
  # wrong in the one case we could check, and a consumer such as
  # load_balancer/gcp wires selector_labels straight into a backend - it would
  # have silently built a load balancer matching no pods. Empty means "not
  # determinable from here", which lets a consumer fail loudly or fall back.
  #
  # service_account_arn IS knowable: it is real whenever workload_identity
  # created a GCP service account, and empty when the chart brings its own.
  output_attributes = {
    namespace           = local.namespace
    resource_name       = local.service_name
    resource_type       = "service"
    service_name        = ""
    selector_labels     = ""
    service_account_arn = try(google_service_account.wi[keys(local.wi_gcp_accounts)[0]].email, "")
  }
}

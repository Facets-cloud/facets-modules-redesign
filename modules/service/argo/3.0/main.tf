# service/argo/3.0
#
# Creates one ArgoCD ApplicationSet per blueprint resource. The generated
# Application carries the facets-argo-shim identity annotations, so
# ${facets:...} references inside the deployed chart resolve against this
# project/environment (see locals.tf for the full contract).
#
# Optionally creates GCP Workload Identity bindings for chart-owned service
# accounts, and a Cloud DNS record.

# Fails the plan when this service uses ${facets:...} references but the wired
# argo_stack has no shim installed. Without this the release succeeds and the
# failure only surfaces later, inside ArgoCD, as a render error Terraform
# cannot see.
resource "terraform_data" "shim_precondition" {
  input = local.shim_enabled

  lifecycle {
    precondition {
      condition = !local.uses_facets_refs || local.shim_enabled
      error_message = join(" ", [
        "This service uses $${facets:...} references, but the wired argo_stack",
        "reports shim_enabled = false. facets-argo-shim must be installed in",
        "argocd-repo-server or every render containing a reference fails closed",
        "inside ArgoCD. Set spec.argocd.facets_shim.enabled = true on the argo",
        "resource (requires argo/gcp >= 1.1), or remove the references from this",
        "service's values.",
      ])
    }
  }
}

module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 63
  resource_name   = var.instance_name
  resource_type   = "service"
  is_k8s          = true
  globally_unique = false
}

module "applicationset" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resources"

  name         = local.service_name
  release_name = module.name.name
  namespace    = local.argocd_namespace

  resources_data = {
    applicationset = local.applicationset
  }

  advanced_config = lookup(lookup(var.instance, "advanced", {}), "service", {})
}

# ── GCP Workload Identity ───────────────────────────────────────────────────
#
# One GCP service account per entry that declares roles, bound to the
# chart-owned Kubernetes ServiceAccount via workloadIdentityUser. The
# annotation linking them is injected into the chart values (see
# local.wi_values) at the values_root the user names - 2.x guessed that root
# from a hardcoded table of CoinSwitch chart names.

module "wi_name" {
  for_each = local.wi_accounts

  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 30 # GCP service account IDs are capped at 30 chars
  resource_name   = "${var.instance_name}-${each.key}"
  resource_type   = "sa"
  globally_unique = false
}

resource "google_service_account" "wi" {
  for_each = local.wi_gcp_accounts

  account_id   = module.wi_name[each.key].name
  display_name = "${var.instance_name} ${each.key} (${var.environment.name})"
  project      = local.project_id
}

resource "google_project_iam_member" "wi_roles" {
  for_each = local.wi_role_bindings

  project = local.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.wi[each.value.account].email}"
}

resource "google_service_account_iam_member" "wi_binding" {
  for_each = local.wi_gcp_accounts

  service_account_id = google_service_account.wi[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member = format(
    "serviceAccount:%s.svc.id.goog[%s/%s]",
    local.project_id,
    local.namespace,
    trimspace(lookup(each.value, "ksa_name", "")) != "" ? each.value.ksa_name : each.key,
  )
}

# ── Cloud DNS ───────────────────────────────────────────────────────────────
#
# Argo renders the chart that creates the Gateway/HTTPRoute, so this module has
# no handle on the address - the target is stated explicitly.

resource "google_dns_record_set" "service" {
  count = local.dns_enabled && length(local.dns_rrdatas) > 0 ? 1 : 0

  project      = local.project_id
  managed_zone = local.dns.zone_name
  name         = endswith(local.dns.name, ".") ? local.dns.name : "${local.dns.name}."
  type         = local.dns_record_type
  ttl          = lookup(local.dns, "ttl", 300)
  rrdatas      = local.dns_rrdatas
}

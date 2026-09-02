locals {
  parent = "folders/${var.inputs.parent_folder.attributes.folder_id}"

  constraints = lookup(var.instance.spec, "constraints", [])

  # deny_all / allow_all / values{} are mutually exclusive in one rules block.
  conflicting_all_rules = sort([
    for c in local.constraints : c.constraint
    if lookup(c, "deny_all", false) && lookup(c, "allow_all", false)
  ])

  # There is no magic "all" value in GCP org policy list constraints. Values are
  # real identifiers — VM instance paths for compute.vmExternalIpAccess, API
  # service names for gcp.restrictNonCmekServices, and so on. A literal "all"
  # matches nothing, so the policy is created, shows as ACTIVE in the console,
  # and enforces NOTHING. Use deny_all/allow_all instead. Caught in review of
  # tier1-baseline, where compute.vmExternalIpAccess had denied_values = ["all"].
  literal_all_values = sort([
    for c in local.constraints : c.constraint
    if contains(coalesce(lookup(c, "denied_values", null), []), "all")
    || contains(coalesce(lookup(c, "allowed_values", null), []), "all")
  ])
}

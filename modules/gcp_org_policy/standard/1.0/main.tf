terraform {
  required_version = ">= 1.0"
}

resource "google_org_policy_policy" "this" {
  for_each = { for c in lookup(var.instance.spec, "constraints", []) : c.constraint => c }

  name   = "${local.parent}/policies/${each.key}"
  parent = local.parent

  lifecycle {
    precondition {
      condition     = length(local.conflicting_all_rules) == 0
      error_message = "gcp_org_policy: deny_all and allow_all are mutually exclusive, both set on: ${join(", ", local.conflicting_all_rules)}."
    }
    precondition {
      condition     = length(local.literal_all_values) == 0
      error_message = "gcp_org_policy: the literal value \"all\" is not special in GCP org policy — it matches no real identifier, so the policy would apply and silently enforce NOTHING. Use deny_all/allow_all instead. Offending constraint(s): ${join(", ", local.literal_all_values)}."
    }
  }

  spec {
    # GCP rejects inherit_from_parent on BOOLEAN constraints outright:
    #   "Error 400: Cannot set InheritFromParent for boolean constraints."
    # Setting it to null omits the field, which is what boolean constraints need.
    inherit_from_parent = each.value.rule_type == "list" ? lookup(each.value, "inherit_from_parent", true) : null

    dynamic "rules" {
      for_each = each.value.rule_type == "boolean" ? [1] : []
      content {
        enforce = lookup(each.value, "enforce", false) ? "TRUE" : "FALSE"
      }
    }

    # A list rule is exactly ONE of: deny_all, allow_all, or values{}.
    # They cannot be combined in the same rules block.
    dynamic "rules" {
      for_each = each.value.rule_type == "list" && lookup(each.value, "deny_all", false) ? [1] : []
      content {
        deny_all = "TRUE"
      }
    }

    dynamic "rules" {
      for_each = each.value.rule_type == "list" && lookup(each.value, "allow_all", false) ? [1] : []
      content {
        allow_all = "TRUE"
      }
    }

    dynamic "rules" {
      for_each = each.value.rule_type == "list" && !lookup(each.value, "deny_all", false) && !lookup(each.value, "allow_all", false) ? [1] : []
      content {
        values {
          allowed_values = lookup(each.value, "allowed_values", null)
          denied_values  = lookup(each.value, "denied_values", null)
        }
      }
    }
  }
}

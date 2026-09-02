locals {
  role_member_pairs = flatten([
    for binding in lookup(var.instance.spec, "bindings", []) : [
      for member in lookup(binding, "members", []) : {
        role   = binding.role
        member = member
      }
    ]
  ])

  role_member_pairs_by_id = {
    for pair in local.role_member_pairs : "${pair.role}|${pair.member}" => pair
  }

  audit_configs_by_service = {
    for cfg in lookup(var.instance.spec, "audit_configs", []) : cfg.service => {
      audit_log_types  = cfg.audit_log_types
      exempted_members = lookup(cfg, "exempted_members", [])
    }
  }
}

locals {
  project_roles_by_id = {
    for role in lookup(var.instance.spec, "project_roles", []) : role => role
  }

  token_creators_by_id = {
    for member in lookup(var.instance.spec, "token_creators", []) : member => member
  }
}

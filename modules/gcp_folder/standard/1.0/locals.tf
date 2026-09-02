locals {
  parent = coalesce(
    try(var.inputs.parent_folder.attributes.folder_name, null),
    var.inputs.cloud_account.attributes.org_name
  )

  deletion_protection = coalesce(try(var.instance.spec.deletion_protection, null), true)
}

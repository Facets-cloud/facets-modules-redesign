resource "kubernetes_service_account_v1" "main" {
  for_each = local.items
  metadata {
    name        = each.value.name
    namespace   = each.value.namespace
    labels      = lookup(each.value, "labels", null)
    annotations = lookup(each.value, "annotations", null)
  }
  automount_service_account_token = lookup(each.value, "automount", true)
  dynamic "image_pull_secret" {
    for_each = lookup(each.value, "image_pull_secret", [])
    content { name = image_pull_secret.value.name }
  }
  dynamic "secret" {
    for_each = lookup(each.value, "secret", [])
    content { name = lookup(secret.value, "name", null) }
  }
  lifecycle {
    # the SA-token controller adds a secret ref + annotations post-create; leave those to it.
    ignore_changes = [secret, metadata[0].annotations]
  }
}

locals {
  spec             = lookup(var.instance, "spec", {})
  priority_classes = lookup(local.spec, "priority_classes", {})
}

# Cluster-scoped PriorityClasses.
# NOTE: `value` and `preemption_policy` are IMMUTABLE on a PriorityClass — when adopting an existing
# one they must match live exactly or the import forces a destroy+recreate, which would leave every
# pod referencing it unschedulable.
resource "kubernetes_priority_class_v1" "priority_class" {
  for_each = local.priority_classes

  metadata {
    name        = each.key
    labels      = lookup(lookup(each.value, "metadata", {}), "labels", null)
    annotations = lookup(lookup(each.value, "metadata", {}), "annotations", null)
  }

  value             = each.value.value
  global_default    = lookup(each.value, "global_default", false)
  description       = lookup(each.value, "description", null)
  preemption_policy = lookup(each.value, "preemption_policy", null)
}

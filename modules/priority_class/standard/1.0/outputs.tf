locals {
  output_interfaces = {}
  output_attributes = {
    # PriorityClasses are cluster-scoped, so there is no namespace; the name lists the managed set.
    resource_name      = join(",", sort([for k, v in kubernetes_priority_class_v1.priority_class : v.metadata[0].name]))
    resource_namespace = ""
  }
}

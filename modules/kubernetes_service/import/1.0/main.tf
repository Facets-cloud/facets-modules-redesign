resource "kubernetes_service_v1" "main" {
  for_each = local.items
  metadata {
    name        = each.value.name
    namespace   = each.value.namespace
    labels      = lookup(each.value, "labels", null)
    annotations = lookup(each.value, "annotations", null)
  }
  spec {
    type                              = each.value.type
    cluster_ip                        = lookup(each.value, "cluster_ip", null)
    selector                          = lookup(each.value, "selector", null)
    ip_families                       = lookup(each.value, "ip_families", null)
    ip_family_policy                  = lookup(each.value, "ip_family_policy", null)
    internal_traffic_policy           = lookup(each.value, "internal_traffic_policy", null)
    external_traffic_policy           = lookup(each.value, "external_traffic_policy", null) != "" ? lookup(each.value, "external_traffic_policy", null) : null
    load_balancer_class               = lookup(each.value, "load_balancer_class", null) != "" ? lookup(each.value, "load_balancer_class", null) : null
    allocate_load_balancer_node_ports = lookup(each.value, "allocate_load_balancer_node_ports", null)

    dynamic "port" {
      for_each = lookup(each.value, "ports", [])
      content {
        name        = port.value.name
        port        = port.value.port
        target_port = port.value.target_port
        protocol    = port.value.protocol
        node_port   = try(port.value.node_port, 0) > 0 ? port.value.node_port : null
      }
    }
  }
  # health_check_node_port / external_ips / source ranges are API-assigned; annotations are
  # controller-managed; wait_for_load_balancer is a client-side create flag.
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      spec[0].port,
      spec[0].ip_families,
      spec[0].health_check_node_port,
      spec[0].external_ips,
      spec[0].load_balancer_source_ranges,
      wait_for_load_balancer,
    ]
  }
}

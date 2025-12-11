locals {
  output_attributes = {
    node_pool_name = azurerm_kubernetes_cluster_node_pool.node_pool.name
    node_pool_id   = azurerm_kubernetes_cluster_node_pool.node_pool.id
    disk_size_gb   = azurerm_kubernetes_cluster_node_pool.node_pool.os_disk_size_gb
    node_count     = azurerm_kubernetes_cluster_node_pool.node_pool.node_count

    # Kubernetes scheduling configurations
    taints        = local.taints
    node_selector = azurerm_kubernetes_cluster_node_pool.node_pool.node_labels
  }
  output_interfaces = {
    placeholder = "{}"
  }
}
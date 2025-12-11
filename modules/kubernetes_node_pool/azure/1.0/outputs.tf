locals {
  output_attributes = {
    node_pool_name = azurerm_kubernetes_cluster_node_pool.node_pool.name
    node_taints    = azurerm_kubernetes_cluster_node_pool.node_pool.node_taints
    node_labels    = azurerm_kubernetes_cluster_node_pool.node_pool.node_labels
    disk_size_gb   = azurerm_kubernetes_cluster_node_pool.node_pool.os_disk_size_gb
    node_count     = azurerm_kubernetes_cluster_node_pool.node_pool.node_count
    node_pool_id   = azurerm_kubernetes_cluster_node_pool.node_pool.id
  }
  output_interfaces = {
  }
}
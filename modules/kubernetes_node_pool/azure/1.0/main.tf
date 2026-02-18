locals {
  aks_advanced              = lookup(lookup(lookup(var.instance, "advanced", {}), "aks", {}), "node_pool", {})
  aks_upgrade_settings      = lookup(local.aks_advanced, "upgrade_settings", {})
  aks_linux_os_config       = lookup(local.aks_advanced, "linux_os_config", {})
  aks_sysctl_config         = lookup(local.aks_linux_os_config, "sysctl_config", {})
  priority                  = lookup(local.aks_advanced, "priority", "Regular")
  user_defined_tags         = lookup(local.aks_advanced, "tags", {})
  facets_defined_cloud_tags = lookup(var.environment, "cloud_tags", {})
  tags                      = merge(local.user_defined_tags, local.facets_defined_cloud_tags)

  name = var.instance_name

  spec           = lookup(var.instance, "spec", {})
  taints         = lookup(local.spec, "taints", [])
  node_taints    = [for taint in local.taints : "${taint.key}=${taint.value}:${taint.effect}"]
  node_labels    = lookup(var.instance.spec, "labels", {})
  spot_max_price = lookup(local.aks_advanced, "spot_max_price", null)
  os_type        = lookup(local.aks_advanced, "os_type", "Linux")
}

resource "azurerm_kubernetes_cluster_node_pool" "node_pool" {
  name                  = local.os_type == "Windows" && length(local.name) >= 6 ? "windos" : local.name
  kubernetes_cluster_id = var.inputs.kubernetes_details.attributes.cluster_id
  vm_size               = var.instance.spec.instance_type
  os_disk_size_gb       = trim(var.instance.spec.disk_size, "G")
  os_type               = local.os_type
  os_disk_type          = lookup(local.aks_advanced, "os_disk_type", "Managed")

  auto_scaling_enabled = lookup(local.aks_advanced, "enable_auto_scaling", true)
  max_count            = var.instance.spec.max_node_count
  min_count            = var.instance.spec.min_node_count
  node_count           = lookup(local.aks_advanced, "node_count", var.instance.spec.min_node_count)
  node_taints          = local.node_taints
  node_labels          = local.node_labels
  max_pods             = lookup(local.aks_advanced, "max_pods", null)

  priority = lookup(local.aks_advanced, "priority", "Regular")

  host_encryption_enabled = lookup(local.aks_advanced, "enable_host_encryption", false)
  node_public_ip_enabled  = lookup(local.aks_advanced, "enable_node_public_ip", false)

  mode                 = lookup(local.aks_advanced, "mode", "User")
  orchestrator_version = lookup(local.aks_advanced, "orchestrator_version", null)
  vnet_subnet_id       = lookup(local.aks_advanced, "vnet_subnet_id", var.inputs.network_details.attributes.private_subnet_ids[0])
  eviction_policy      = local.priority == "Spot" ? lookup(local.aks_advanced, "eviction_policy", "Delete") : null

  tags           = local.tags
  spot_max_price = local.priority == "Spot" ? lookup(local.aks_advanced, "spot_max_price", "-1") : local.spot_max_price
  zones          = length(compact(lookup(var.environment, "azs", []))) == 0 ? null : [lookup(var.environment, "azs", [])[0]]

  dynamic "linux_os_config" {
    for_each = length(local.aks_linux_os_config) > 0 ? [local.aks_linux_os_config] : []
    content {
      swap_file_size_mb             = lookup(linux_os_config.value, "swap_file_size_mb", null)
      transparent_huge_page_enabled = lookup(linux_os_config.value, "transparent_huge_page_enabled", null)
      transparent_huge_page_defrag  = lookup(linux_os_config.value, "transparent_huge_page_defrag", null)

      dynamic "sysctl_config" {
        for_each = length(local.aks_sysctl_config) > 0 ? [local.aks_sysctl_config] : []
        content {
          fs_aio_max_nr                      = lookup(sysctl_config.value, "fs_aio_max_nr", null)
          fs_file_max                        = lookup(sysctl_config.value, "fs_file_max", null)
          fs_inotify_max_user_watches        = lookup(sysctl_config.value, "fs_inotify_max_user_watches", null)
          fs_nr_open                         = lookup(sysctl_config.value, "fs_nr_open", null)
          kernel_threads_max                 = lookup(sysctl_config.value, "kernel_threads_max", null)
          net_core_netdev_max_backlog        = lookup(sysctl_config.value, "net_core_netdev_max_backlog", null)
          net_core_optmem_max                = lookup(sysctl_config.value, "net_core_optmem_max", null)
          net_core_rmem_default              = lookup(sysctl_config.value, "net_core_rmem_default", null)
          net_core_rmem_max                  = lookup(sysctl_config.value, "net_core_rmem_max", null)
          net_core_somaxconn                 = lookup(sysctl_config.value, "net_core_somaxconn", null)
          net_core_wmem_default              = lookup(sysctl_config.value, "net_core_wmem_default", null)
          net_core_wmem_max                  = lookup(sysctl_config.value, "net_core_wmem_max", null)
          net_ipv4_ip_local_port_range_max   = lookup(sysctl_config.value, "net_ipv4_ip_local_port_range_max", null)
          net_ipv4_ip_local_port_range_min   = lookup(sysctl_config.value, "net_ipv4_ip_local_port_range_min", null)
          net_ipv4_neigh_default_gc_thresh1  = lookup(sysctl_config.value, "net_ipv4_neigh_default_gc_thresh1", null)
          net_ipv4_neigh_default_gc_thresh2  = lookup(sysctl_config.value, "net_ipv4_neigh_default_gc_thresh2", null)
          net_ipv4_neigh_default_gc_thresh3  = lookup(sysctl_config.value, "net_ipv4_neigh_default_gc_thresh3", null)
          net_ipv4_tcp_fin_timeout           = lookup(sysctl_config.value, "net_ipv4_tcp_fin_timeout", null)
          net_ipv4_tcp_keepalive_intvl       = lookup(sysctl_config.value, "net_ipv4_tcp_keepalive_intvl", null)
          net_ipv4_tcp_keepalive_probes      = lookup(sysctl_config.value, "net_ipv4_tcp_keepalive_probes", null)
          net_ipv4_tcp_keepalive_time        = lookup(sysctl_config.value, "net_ipv4_tcp_keepalive_time", null)
          net_ipv4_tcp_max_syn_backlog       = lookup(sysctl_config.value, "net_ipv4_tcp_max_syn_backlog", null)
          net_ipv4_tcp_max_tw_buckets        = lookup(sysctl_config.value, "net_ipv4_tcp_max_tw_buckets", null)
          net_ipv4_tcp_tw_reuse              = lookup(sysctl_config.value, "net_ipv4_tcp_tw_reuse", null)
          net_netfilter_nf_conntrack_buckets = lookup(sysctl_config.value, "net_netfilter_nf_conntrack_buckets", null)
          net_netfilter_nf_conntrack_max     = lookup(sysctl_config.value, "net_netfilter_nf_conntrack_max", null)
          vm_max_map_count                   = lookup(sysctl_config.value, "vm_max_map_count", null)
          vm_swappiness                      = lookup(sysctl_config.value, "vm_swappiness", null)
          vm_vfs_cache_pressure              = lookup(sysctl_config.value, "vm_vfs_cache_pressure", null)
        }
      }
    }
  }

  dynamic "upgrade_settings" {
    for_each = local.priority == "Regular" ? [1] : []
    content {
      max_surge = lookup(local.aks_upgrade_settings, "max_surge", "10%")
    }
  }

  timeouts {
    create = "60m"
    delete = "2h"
  }

  lifecycle {
    ignore_changes = [node_count, kubernetes_cluster_id, zones, orchestrator_version, name, ultra_ssd_enabled, scale_down_mode, fips_enabled, kubelet_disk_type, os_sku, windows_profile]
  }
}

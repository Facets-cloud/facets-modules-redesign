# Deploy NodeClass using any-k8s-resource for rollback capabilities
module "node_class" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource?ref=3b222c02b481f2517be1a794a2b9b6184e140b19"

  name      = local.node_class_name
  namespace = "karpenter"
  data      = local.node_class_manifest

  advanced_config = {
    enable_rollback = true
    wait_for_ready  = true
    timeout_seconds = 300
  }
}

# Deploy NodePool using any-k8s-resource for rollback capabilities
module "node_pool" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource?ref=3b222c02b481f2517be1a794a2b9b6184e140b19"

  # Ensure NodeClass is created first
  depends_on = [module.node_class]

  name      = local.node_pool_name
  namespace = "karpenter"
  data      = local.node_pool_manifest

  advanced_config = {
    enable_rollback = true
    wait_for_ready  = true
    timeout_seconds = 300
  }
}

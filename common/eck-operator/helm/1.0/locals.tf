locals {
  spec      = var.instance.spec
  namespace = lookup(var.instance, "namespace", "elastic-system")
  
  # Helm chart configuration
  repository        = "https://helm.elastic.co"
  chart_name        = "eck-operator"
  chart_version     = lookup(local.spec, "chart_version", "2.14.0")
  create_namespace  = lookup(local.spec, "create_namespace", true)
  
  # Get Kubernetes cluster details
  k8s_cluster_input = lookup(var.inputs, "kubernetes_cluster", {})
  k8s_cluster_attrs = lookup(local.k8s_cluster_input, "attributes", {})
  
  # Helm values
  helm_values = lookup(local.spec, "helm_values", {})
  
  # Default values for ECK Operator
  default_values = {
    installCRDs = true
    managedNamespaces = ["elastic-system"]
    resources = {
      limits = {
        cpu    = "1"
        memory = "1Gi"
      }
      requests = {
        cpu    = "100m"
        memory = "150Mi"
      }
    }
  }
  
  # Merge default and custom values
  final_values = merge(local.default_values, local.helm_values)
}
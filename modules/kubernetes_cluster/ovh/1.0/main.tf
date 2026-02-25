# OVH Managed Kubernetes Service (MKS) Cluster Module
# Creates a managed Kubernetes cluster and exposes K8s and Helm providers

locals {
  # Get region from network input
  region = var.inputs.network.attributes.region

  # Cluster name computed from environment and instance name for uniqueness
  cluster_name = "${var.environment.unique_name}-${var.instance_name}"
}

# Create the managed Kubernetes cluster
resource "ovh_cloud_project_kube" "cluster" {
  service_name = var.inputs.ovh_provider.attributes.project_id
  name         = local.cluster_name
  region       = local.region

  # Cluster configuration
  plan            = var.instance.spec.plan
  version         = null       # Always use latest Kubernetes version
  kube_proxy_mode = "iptables" # Hardcoded to iptables for consistency

  # Network configuration
  private_network_id = var.inputs.network.attributes.openstack_network_id
  nodes_subnet_id    = var.inputs.network.attributes.k8s_subnet_id

  # Private network routing configuration - hardcoded for security best practices
  private_network_configuration {
    default_vrack_gateway              = ""   # Use DHCP gateway from K8s subnet
    private_network_routing_as_default = true # Route through private network for better isolation
  }

  # Set update policy to allow automatic updates
  update_policy = "MINIMAL_DOWNTIME"

  timeouts {
    create = "30m"
    update = "30m"
    delete = "20m"
  }
}
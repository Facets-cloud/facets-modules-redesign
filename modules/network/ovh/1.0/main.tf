# OVH Network Module for Kubernetes
# Creates private network with multiple subnets for K8s, databases, and load balancers

locals {
  # Map human-readable region names to OVH region codes
  region_map = {
    "Beauharnois, Canada (BHS5)"       = "BHS5"
    "Frankfurt, Germany (DE1)"         = "DE1"
    "Paris, France 3-AZ (EU-WEST-PAR)" = "EU-WEST-PAR"
    "Gravelines, France (GRA9)"        = "GRA9"
    "Roubaix, France (RBX-A)"          = "RBX-A"
    "Strasbourg, France (SBG5)"        = "SBG5"
    "London, UK (UK1)"                 = "UK1"
    "Warsaw, Poland (WAW1)"            = "WAW1"
  }

  # Get the region code from the human-readable dropdown value
  region = local.region_map[var.instance.spec.region]

  # Parse CIDR for subnet configuration
  cidr_parts      = split("/", var.instance.spec.network_cidr)
  network_address = local.cidr_parts[0]

  # Subnet allocations from the base network (assuming /16)
  # K8s subnet: 10.x.0.0/22 (1024 IPs) - .0.0 to .3.255
  k8s_subnet_cidr  = cidrsubnet(var.instance.spec.network_cidr, 6, 0) # /16 + 6 = /22
  k8s_subnet_start = cidrhost(local.k8s_subnet_cidr, 10)
  k8s_subnet_end   = cidrhost(local.k8s_subnet_cidr, -10)

  # Database subnet: 10.x.4.0/24 (256 IPs) - .4.0 to .4.255
  db_subnet_cidr  = cidrsubnet(var.instance.spec.network_cidr, 8, 4) # /16 + 8 = /24, offset 4
  db_subnet_start = cidrhost(local.db_subnet_cidr, 10)
  db_subnet_end   = cidrhost(local.db_subnet_cidr, -10)

  # Load balancer subnet: 10.x.5.0/24 (256 IPs) - .5.0 to .5.255
  lb_subnet_cidr  = cidrsubnet(var.instance.spec.network_cidr, 8, 5) # /16 + 8 = /24, offset 5
  lb_subnet_start = cidrhost(local.lb_subnet_cidr, 10)
  lb_subnet_end   = cidrhost(local.lb_subnet_cidr, -10)
}

# Retrieve project details using project_id from provider
data "ovh_cloud_project" "project" {
  service_name = var.inputs.ovh_provider.attributes.project_id
}

# Create private network
resource "ovh_cloud_project_network_private" "network" {
  service_name = data.ovh_cloud_project.project.service_name
  name         = "${var.environment.unique_name}-${var.instance_name}-network"
  regions      = [local.region]
  vlan_id      = var.instance.spec.vlan_id # Required VLAN ID, must be unique per OVH account
}

# K8s subnet - with gateway for internet access
resource "ovh_cloud_project_network_private_subnet" "k8s_subnet" {
  service_name = data.ovh_cloud_project.project.service_name
  network_id   = ovh_cloud_project_network_private.network.id
  region       = local.region
  start        = local.k8s_subnet_start
  end          = local.k8s_subnet_end
  network      = local.k8s_subnet_cidr
  dhcp         = true
  no_gateway   = false # K8s subnet needs gateway for internet access
}

# Database subnet - no gateway needed (private only)
resource "ovh_cloud_project_network_private_subnet" "db_subnet" {
  service_name = data.ovh_cloud_project.project.service_name
  network_id   = ovh_cloud_project_network_private.network.id
  region       = local.region
  start        = local.db_subnet_start
  end          = local.db_subnet_end
  network      = local.db_subnet_cidr
  dhcp         = true
  no_gateway   = true # Database subnet is private only
}

# Load balancer subnet - no gateway needed (private only)
resource "ovh_cloud_project_network_private_subnet" "lb_subnet" {
  service_name = data.ovh_cloud_project.project.service_name
  network_id   = ovh_cloud_project_network_private.network.id
  region       = local.region
  start        = local.lb_subnet_start
  end          = local.lb_subnet_end
  network      = local.lb_subnet_cidr
  dhcp         = true
  no_gateway   = true # LB subnet is private only
}

# Create gateway for K8s subnet only (fixed size 's')
resource "ovh_cloud_project_gateway" "gateway" {
  service_name = data.ovh_cloud_project.project.service_name
  name         = "${var.environment.unique_name}-${var.instance_name}-gateway"
  model        = "s" # Fixed to small size
  region       = local.region
  network_id   = tolist(ovh_cloud_project_network_private.network.regions_attributes[*].openstackid)[0]
  subnet_id    = ovh_cloud_project_network_private_subnet.k8s_subnet.id
}
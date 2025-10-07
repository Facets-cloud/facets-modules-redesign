# Data source to get compute zones in the region
data "google_compute_zones" "available" {
  region = local.gcp_region
  status = "UP"
}

# Local values for simplified GKE-optimized calculations
locals {
  # Extract commonly used values to avoid repeated lookups
  spec             = var.instance.spec
  vpc_cidr         = local.spec.vpc_cidr
  enable_flow_logs = lookup(local.spec, "enable_flow_logs", false)
  firewall_rules = lookup(local.spec, "firewall_rules", {
    allow_internal = true
    allow_ssh      = true
    allow_http     = false
    allow_https    = true
    allow_icmp     = true
  })
  labels_spec = lookup(local.spec, "labels", {})
  gcp_region  = var.inputs.cloud_account.attributes.region
  gcp_project = var.inputs.cloud_account.attributes.project_id

  # GCP uses regional subnets, not zonal like AWS
  # We'll create regional subnets that span all zones

  # Fixed subnet allocation for GKE-optimized VPC
  # VPC: /16 (65,536 IPs)
  # Private: /19 (8,192 IPs) - for general workloads + GKE nodes
  # Public: /24 (256 IPs) - for NAT + public-facing resources
  # Database: /24 (256 IPs) - for Cloud SQL + managed databases
  # Internal LB: /24 (256 IPs) - for GKE internal load balancers
  # Google Services: /20 (4,096 IPs) - for managed services peering
  vpc_prefix             = 16
  private_subnet_prefix  = 19 # 8,192 IPs
  public_subnet_prefix   = 24 # 256 IPs
  database_subnet_prefix = 24 # 256 IPs
  internal_lb_prefix     = 24 # 256 IPs for GKE LBs
  google_services_prefix = 20 # 4,096 IPs for managed services

  # GKE secondary ranges (for pods and services)
  gke_pods_prefix     = 18 # 16,384 IPs for pods
  gke_services_prefix = 20 # 4,096 IPs for services

  # Calculate newbits for cidrsubnets function
  private_newbits         = local.private_subnet_prefix - local.vpc_prefix  # 19 - 16 = 3
  public_newbits          = local.public_subnet_prefix - local.vpc_prefix   # 24 - 16 = 8
  database_newbits        = local.database_subnet_prefix - local.vpc_prefix # 24 - 16 = 8
  internal_lb_newbits     = local.internal_lb_prefix - local.vpc_prefix     # 24 - 16 = 8
  google_services_newbits = local.google_services_prefix - local.vpc_prefix # 20 - 16 = 4
  gke_pods_newbits        = local.gke_pods_prefix - local.vpc_prefix        # 18 - 16 = 2
  gke_services_newbits    = local.gke_services_prefix - local.vpc_prefix    # 20 - 16 = 4

  # Create ordered list of newbits for cidrsubnets function
  # Order: private, public, database, internal_lb, google_services, gke_pods, gke_services
  all_subnet_newbits = [
    local.private_newbits,
    local.public_newbits,
    local.database_newbits,
    local.internal_lb_newbits,
    local.google_services_newbits,
    local.gke_pods_newbits,
    local.gke_services_newbits
  ]

  # Generate all subnet CIDRs using cidrsubnets function - prevents overlaps
  all_subnet_cidrs = cidrsubnets(local.vpc_cidr, local.all_subnet_newbits...)

  # Extract subnet CIDRs by purpose
  private_subnet_cidr         = local.all_subnet_cidrs[0] # /19
  public_subnet_cidr          = local.all_subnet_cidrs[1] # /24
  database_subnet_cidr        = local.all_subnet_cidrs[2] # /24
  internal_lb_subnet_cidr     = local.all_subnet_cidrs[3] # /24
  google_services_subnet_cidr = local.all_subnet_cidrs[4] # /20
  gke_pods_subnet_cidr        = local.all_subnet_cidrs[5] # /18
  gke_services_subnet_cidr    = local.all_subnet_cidrs[6] # /20

  # Calculate IP allocation summary
  total_private_ips  = 8192  # /19
  total_public_ips   = 256   # /24
  total_database_ips = 256   # /24
  total_internal_lb  = 256   # /24
  total_google_svc   = 4096  # /20
  total_gke_pods     = 16384 # /18
  total_gke_services = 4096  # /20
  total_used_ips = (local.total_private_ips + local.total_public_ips + local.total_database_ips +
    local.total_internal_lb + local.total_google_svc + local.total_gke_pods +
  local.total_gke_services)
  reserved_ips = 65536 - local.total_used_ips

  # Resource naming prefix (using name module)
  name_prefix = module.name.name

  # Common labels for all resources
  common_labels = merge(
    {
      environment = var.environment.name
    },
    local.labels_spec,
    var.environment.cloud_tags
  )

  # Network tags for firewall rules
  network_tags = {
    ssh_access   = "${local.name_prefix}-ssh-access"
    http_server  = "${local.name_prefix}-http-server"
    https_server = "${local.name_prefix}-https-server"
    gke_nodes    = "${local.name_prefix}-gke-nodes"
  }
}

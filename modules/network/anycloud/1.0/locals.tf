# Anycloud network: branch on the cloud_provider published by the LINKED cloud_account.
# Subnets are auto-calculated from the /16 base CIDR (cidrsubnets) for optimal K8s/GKE allocation.
locals {
  cloud_provider = var.inputs.cloud_account.attributes.cloud_provider
  is_aws         = local.cloud_provider == "AWS"
  is_gcp         = local.cloud_provider == "GCP"

  spec = var.instance.spec
  cidr = try(local.spec.cidr, "10.0.0.0/16")

  # region/project come from the linked account (nested aws.*/gcp.*), not the module spec
  aws_region  = try(var.inputs.cloud_account.attributes.aws.region, null)
  gcp_region  = try(var.inputs.cloud_account.attributes.gcp.region, null)
  gcp_project = try(var.inputs.cloud_account.attributes.gcp.project_id, null)

  # name_prefix from name.tf (spec.name override or name util)
  name_prefix = local.resource_name

  common_tags = merge(
    try(var.environment.cloud_tags, {}),
    try(local.spec.aws.tags, {}),
    {
      Name        = local.name_prefix
      Environment = var.environment.name
    }
  )
  common_labels = merge(
    { environment = var.environment.name },
    try(local.spec.gcp.labels, {}),
    try(var.environment.cloud_tags, {})
  )

  # ───────────────────────────── AWS ─────────────────────────────
  aws_auto_select_azs = try(local.spec.aws.auto_select_azs, true)
  aws_az_list_spec    = try(local.spec.aws.availability_zones, [])
  aws_selected_azs = local.is_aws ? (
    local.aws_auto_select_azs ? (
      length(data.aws_availability_zones.available[0].names) >= 3 ?
      slice(data.aws_availability_zones.available[0].names, 0, 3) :
      data.aws_availability_zones.available[0].names
    ) : local.aws_az_list_spec
  ) : []
  aws_num_azs = length(local.aws_selected_azs)

  # Fixed K8s allocation off /16: private /19 (8K/AZ), public /24, database /24.
  aws_private_newbits  = 3 # 19 - 16
  aws_public_newbits   = 8 # 24 - 16
  aws_database_newbits = 8 # 24 - 16
  aws_all_newbits = concat(
    [for i in range(local.aws_num_azs) : local.aws_private_newbits],
    [for i in range(local.aws_num_azs) : local.aws_public_newbits],
    [for i in range(local.aws_num_azs) : local.aws_database_newbits],
  )
  aws_all_cidrs      = (local.is_aws && local.aws_num_azs > 0) ? cidrsubnets(local.cidr, local.aws_all_newbits...) : []
  aws_private_cidrs  = local.is_aws ? slice(local.aws_all_cidrs, 0, local.aws_num_azs) : []
  aws_public_cidrs   = local.is_aws ? slice(local.aws_all_cidrs, local.aws_num_azs, local.aws_num_azs * 2) : []
  aws_database_cidrs = local.is_aws ? slice(local.aws_all_cidrs, local.aws_num_azs * 2, local.aws_num_azs * 3) : []

  aws_private_subnets  = [for i in range(local.aws_num_azs) : { az = local.aws_selected_azs[i], cidr_block = local.aws_private_cidrs[i] }]
  aws_public_subnets   = [for i in range(local.aws_num_azs) : { az = local.aws_selected_azs[i], cidr_block = local.aws_public_cidrs[i] }]
  aws_database_subnets = [for i in range(local.aws_num_azs) : { az = local.aws_selected_azs[i], cidr_block = local.aws_database_cidrs[i] }]

  aws_nat_strategy = try(local.spec.aws.nat_gateway.strategy, "single")

  aws_vpc_endpoints = {
    enable_s3           = try(local.spec.aws.vpc_endpoints.enable_s3, true)
    enable_dynamodb     = try(local.spec.aws.vpc_endpoints.enable_dynamodb, true)
    enable_ecr_api      = try(local.spec.aws.vpc_endpoints.enable_ecr_api, true)
    enable_ecr_dkr      = try(local.spec.aws.vpc_endpoints.enable_ecr_dkr, true)
    enable_eks          = try(local.spec.aws.vpc_endpoints.enable_eks, false)
    enable_ec2          = try(local.spec.aws.vpc_endpoints.enable_ec2, false)
    enable_ssm          = try(local.spec.aws.vpc_endpoints.enable_ssm, true)
    enable_ssm_messages = try(local.spec.aws.vpc_endpoints.enable_ssm_messages, true)
    enable_ec2_messages = try(local.spec.aws.vpc_endpoints.enable_ec2_messages, true)
    enable_kms          = try(local.spec.aws.vpc_endpoints.enable_kms, false)
    enable_logs         = try(local.spec.aws.vpc_endpoints.enable_logs, false)
    enable_monitoring   = try(local.spec.aws.vpc_endpoints.enable_monitoring, false)
    enable_sts          = try(local.spec.aws.vpc_endpoints.enable_sts, false)
    enable_lambda       = try(local.spec.aws.vpc_endpoints.enable_lambda, false)
  }
  aws_any_interface_endpoint = anytrue([
    local.aws_vpc_endpoints.enable_ecr_api, local.aws_vpc_endpoints.enable_ecr_dkr,
    local.aws_vpc_endpoints.enable_eks, local.aws_vpc_endpoints.enable_ec2,
    local.aws_vpc_endpoints.enable_ssm, local.aws_vpc_endpoints.enable_ssm_messages,
    local.aws_vpc_endpoints.enable_ec2_messages, local.aws_vpc_endpoints.enable_kms,
    local.aws_vpc_endpoints.enable_logs, local.aws_vpc_endpoints.enable_monitoring,
    local.aws_vpc_endpoints.enable_sts, local.aws_vpc_endpoints.enable_lambda,
  ])

  eks_public_tags  = { "kubernetes.io/role/elb" = "1" }
  eks_private_tags = { "kubernetes.io/role/internal-elb" = "1" }

  # ───────────────────────────── GCP ─────────────────────────────
  gcp_enable_flow_logs = try(local.spec.gcp.enable_flow_logs, false)
  gcp_firewall_rules = {
    allow_internal = try(local.spec.gcp.firewall_rules.allow_internal, true)
    allow_ssh      = try(local.spec.gcp.firewall_rules.allow_ssh, true)
    allow_http     = try(local.spec.gcp.firewall_rules.allow_http, false)
    allow_https    = try(local.spec.gcp.firewall_rules.allow_https, true)
    allow_icmp     = try(local.spec.gcp.firewall_rules.allow_icmp, true)
  }
  gcp_auto_select_zones = try(local.spec.gcp.auto_select_zones, true)
  gcp_zones_spec        = try(local.spec.gcp.zones, [])
  gcp_selected_zones = local.is_gcp ? (
    local.gcp_auto_select_zones ?
    slice(data.google_compute_zones.available[0].names, 0, min(3, length(data.google_compute_zones.available[0].names))) :
    local.gcp_zones_spec
  ) : []

  vpc_connector_enabled       = try(local.spec.gcp.vpc_connector.enabled, false)
  vpc_connector_machine_type  = try(local.spec.gcp.vpc_connector.machine_type, "e2-micro")
  vpc_connector_min_instances = try(local.spec.gcp.vpc_connector.min_instances, 2)
  vpc_connector_max_instances = try(local.spec.gcp.vpc_connector.max_instances, 3)

  # Fixed GKE allocation off /16, in cidrsubnets order:
  # private /19, public /24, database /24, internal_lb /24, google_services /20, gke_pods /18, gke_services /20, vpc_connector /28
  gcp_newbits   = [3, 8, 8, 8, 4, 2, 4, 12]
  gcp_all_cidrs = cidrsubnets(local.cidr, local.gcp_newbits...)

  gcp_private_subnet_cidr       = local.gcp_all_cidrs[0]
  gcp_public_subnet_cidr        = local.gcp_all_cidrs[1]
  gcp_database_subnet_cidr      = local.gcp_all_cidrs[2]
  gcp_internal_lb_subnet_cidr   = local.gcp_all_cidrs[3]
  gcp_google_services_cidr      = local.gcp_all_cidrs[4]
  gcp_gke_pods_subnet_cidr      = local.gcp_all_cidrs[5]
  gcp_gke_services_subnet_cidr  = local.gcp_all_cidrs[6]
  gcp_vpc_connector_subnet_cidr = local.gcp_all_cidrs[7]
  gcp_google_services_prefix    = 20

  gcp_network_tags = {
    ssh_access   = "${local.name_prefix}-ssh-access"
    http_server  = "${local.name_prefix}-http-server"
    https_server = "${local.name_prefix}-https-server"
    gke_nodes    = "${local.name_prefix}-gke-nodes"
  }
}

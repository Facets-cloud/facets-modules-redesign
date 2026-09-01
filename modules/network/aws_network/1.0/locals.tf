data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  spec       = var.instance.spec
  aws_region = var.inputs.cloud_account.attributes.aws_region

  # ── posture ───────────────────────────────────────────────────────────────
  imports   = lookup(local.spec, "imports", {})
  importing = try(local.imports.import_existing, false)

  # A plan is DECLARED when the operator states topology explicitly.
  # Adoption always declares - and now that is ENFORCED, not a convention. The
  # greenfield-only fields (auto_select_azs, availability_zones, nat_strategy) are
  # hidden while adopting, so the derivation maths they feed must be provably
  # unreachable rather than merely unused in practice.
  declared = local.importing || length(lookup(local.spec, "subnets", {})) > 0

  # ── derived plan (1.0 maths, byte-for-byte) ───────────────────────────────
  auto_select_azs    = lookup(local.spec, "auto_select_azs", true)
  availability_zones = lookup(local.spec, "availability_zones", [])
  vpc_cidr           = local.spec.vpc_cidr
  nat_strategy       = lookup(local.spec, "nat_strategy", "single")

  selected_azs = local.auto_select_azs ? (
    length(data.aws_availability_zones.available.names) >= 3 ?
    slice(data.aws_availability_zones.available.names, 0, 3) :
    data.aws_availability_zones.available.names
  ) : local.availability_zones

  num_azs = length(local.selected_azs)

  # Fixed K8s-optimized allocation, identical to 1.0:
  #   private /19 per AZ, public /24 per AZ, database /24 per AZ
  derived_newbits = concat(
    [for i in range(local.num_azs) : 3],
    [for i in range(local.num_azs) : 8],
    [for i in range(local.num_azs) : 8],
  )
  derived_cidrs = local.declared ? [] : cidrsubnets(local.vpc_cidr, local.derived_newbits...)

  derived_subnets = local.declared ? {} : merge(
    { for i, az in local.selected_azs : "private-${az}" => {
      availability_zone       = az
      cidr_block              = local.derived_cidrs[i]
      tier                    = "private"
      map_public_ip_on_launch = false
      route_table_key         = local.nat_strategy == "per_az" ? "private-${az}" : "private-single"
      associate_route_table   = true
      name                    = null
      tags                    = null
    } },
    { for i, az in local.selected_azs : "public-${az}" => {
      availability_zone       = az
      cidr_block              = local.derived_cidrs[local.num_azs + i]
      tier                    = "public"
      map_public_ip_on_launch = true
      route_table_key         = "public"
      associate_route_table   = true
      name                    = null
      tags                    = null
    } },
    { for i, az in local.selected_azs : "database-${az}" => {
      availability_zone       = az
      cidr_block              = local.derived_cidrs[(local.num_azs * 2) + i]
      tier                    = "database"
      map_public_ip_on_launch = false
      route_table_key         = "database-${az}"
      associate_route_table   = true
      name                    = null
      tags                    = null
    } },
  )

  derived_nat_keys = local.nat_strategy == "per_az" ? local.selected_azs : ["single"]
  derived_nats = local.declared ? {} : {
    for k in local.derived_nat_keys : k => {
      subnet_key = local.nat_strategy == "per_az" ? "public-${k}" : "public-${local.selected_azs[0]}"
      name       = null
      tags       = null
      eip_tags   = null
    }
  }

  derived_route_tables = local.declared ? {} : merge(
    { public = {
      is_main = false
      name    = null
      tags    = null
      routes  = { "0.0.0.0/0" = { target_type = "internet_gateway", nat_gateway_key = null } }
    } },
    local.nat_strategy == "per_az" ? {
      for az in local.selected_azs : "private-${az}" => {
        is_main = false
        name    = null
        tags    = null
        routes  = { "0.0.0.0/0" = { target_type = "nat_gateway", nat_gateway_key = az } }
      }
      } : {
      private-single = {
        is_main = false
        name    = null
        tags    = null
        routes  = { "0.0.0.0/0" = { target_type = "nat_gateway", nat_gateway_key = "single" } }
      }
    },
    # database route tables are isolated - no egress routes
    { for az in local.selected_azs : "database-${az}" => {
      is_main = false
      name    = null
      tags    = null
      routes  = {}
    } },
  )

  # ── effective plan: declared wins, derived otherwise ──────────────────────
  subnets = local.declared ? {
    for k, s in local.spec.subnets : k => {
      availability_zone       = s.availability_zone
      cidr_block              = s.cidr_block
      tier                    = s.tier
      map_public_ip_on_launch = lookup(s, "map_public_ip_on_launch", false)
      route_table_key         = lookup(s, "route_table_key", null)
      associate_route_table   = lookup(s, "associate_route_table", true)
      name                    = lookup(s, "name", null)
      tags                    = lookup(s, "tags", null)
    }
  } : local.derived_subnets

  route_tables = local.declared ? {
    for k, rt in lookup(local.spec, "route_tables", {}) : k => {
      is_main = lookup(rt, "is_main", false)
      name    = lookup(rt, "name", null)
      tags    = lookup(rt, "tags", null)
      routes  = lookup(rt, "routes", {})
    }
  } : local.derived_route_tables

  nat_gateways = local.declared ? {
    for k, n in lookup(local.spec, "nat_gateways", {}) : k => {
      subnet_key = n.subnet_key
      name       = lookup(n, "name", null)
      tags       = lookup(n, "tags", null)
      eip_tags   = lookup(n, "eip_tags", null)
    }
  } : local.derived_nats

  # Flattened routes, keyed "<route-table>|<destination>" - matches the import ids.
  # The destination is the inner map key, so a table cannot express two routes to the
  # same destination - what used to be a duplicate-key crash at apply is now unsayable.
  routes = merge(concat([{}], [
    for rk, rt in local.route_tables : {
      for dest, route in rt.routes : "${rk}|${dest}" => {
        route_table_key = rk
        destination     = dest
        target_type     = route.target_type
        nat_gateway_key = lookup(route, "nat_gateway_key", null)
      }
    }
  ])...)

  # Only subnets that ask for an association get one. false => inherit the main table.
  subnet_associations = {
    for k, s in local.subnets : k => s
    if s.associate_route_table && s.route_table_key != null
  }

  main_route_table_key = one([for k, rt in local.route_tables : k if rt.is_main])

  # ── naming and tags ───────────────────────────────────────────────────────
  name_prefix = "${var.environment.unique_name}-${var.instance_name}"
  common_tags = merge(
    var.environment.cloud_tags,
    lookup(local.spec, "additional_tags", {}),
    { Name = local.name_prefix, Environment = var.environment.name },
  )
  eks_public_tags  = { "kubernetes.io/role/elb" = "1" }
  eks_private_tags = { "kubernetes.io/role/internal-elb" = "1" }

  # ── endpoints ─────────────────────────────────────────────────────────────
  # E2 — ENFORCED, not convention. Under adoption an AWS-service endpoint is managed
  # if and only if vpc_endpoints.pins.<key>.import_id names a live endpoint. A toggle
  # left true by the base blueprint therefore cannot create an endpoint on a live VPC;
  # only a supplied id can bring one under management.
  ep_spec = lookup(local.spec, "vpc_endpoints", {})
  ep_ids  = [for k, v in lookup(local.ep_spec, "pins", {}) : k if lookup(v, "import_id", null) != null]

  ep_schema_default = {
    s3             = true, dynamodb = true, ecr_api = true, ecr_dkr = true
    ssm            = true, ssm_messages = true, ec2_messages = true
    eks            = false, ec2 = false, kms = false, logs = false
    monitoring     = false, sts = false, lambda = false
    secretsmanager = false, sqs = false
  }

  endpoints = {
    for k, d in local.ep_schema_default : k => (
      local.importing
      ? contains(local.ep_ids, k)
      : lookup(local.ep_spec, "enable_${k}", d)
    )
  }

  gateway_endpoints = { for k in ["s3", "dynamodb"] : k => true if local.endpoints[k] }
  interface_endpoint_names = [
    "ecr_api", "ecr_dkr", "ssm", "ssm_messages", "ec2_messages", "eks", "ec2",
    "kms", "logs", "monitoring", "sts", "lambda", "secretsmanager", "sqs",
  ]
  interface_endpoints = { for k in local.interface_endpoint_names : k => true if local.endpoints[k] }

  ep_service_name = {
    ecr_api        = "ecr.api"
    ecr_dkr        = "ecr.dkr"
    ssm            = "ssm"
    ssm_messages   = "ssmmessages"
    ec2_messages   = "ec2messages"
    eks            = "eks"
    ec2            = "ec2"
    kms            = "kms"
    logs           = "logs"
    monitoring     = "monitoring"
    sts            = "sts"
    lambda         = "lambda"
    secretsmanager = "secretsmanager"
    sqs            = "sqs"
  }

  # E5 - adopted AWS-service endpoints carry live attributes the toggles cannot
  # express. `vpc_endpoints.overrides` pins them per endpoint key; anything left
  # unset is derived exactly as before. Each pin is its own homogeneous map so
  # heterogeneous per-endpoint objects never have to unify.
  ep_ovr = lookup(local.ep_spec, "pins", {})

  ep_ovr_subnets = {
    for k, v in local.ep_ovr : k => tolist([for s in lookup(v, "subnet_keys", []) : tostring(s)])
    if length(lookup(v, "subnet_keys", [])) > 0
  }
  ep_ovr_rtbs = {
    for k, v in local.ep_ovr : k => tolist([for s in lookup(v, "route_table_keys", []) : tostring(s)])
    if length(lookup(v, "route_table_keys", [])) > 0
  }
  ep_ovr_sgs = {
    for k, v in local.ep_ovr : k => tolist([for s in lookup(v, "security_group_ids", []) : tostring(s)])
    if length(lookup(v, "security_group_ids", [])) > 0
  }
  ep_ovr_dns = {
    for k, v in local.ep_ovr : k => tobool(v.private_dns_enabled)
    if can(v.private_dns_enabled)
  }
  ep_ovr_tags = {
    for k, v in local.ep_ovr : k => tomap({ for tk, tv in lookup(v, "tags", {}) : tk => tostring(tv) })
    if lookup(v, "tags", null) != null
  }

  # Custom/PrivateLink endpoints follow the same rule under adoption.
  custom_endpoints_all = lookup(local.ep_spec, "custom", {})
  custom_endpoints = {
    for k, c in local.custom_endpoints_all : k => c
    if !local.importing || lookup(c, "import_id", null) != null
  }

  # The module only creates its own endpoint SG for endpoints IT creates. During
  # adoption every endpoint brings its live security groups, so no SG is made.
  create_endpoint_sg = !local.importing && length(local.interface_endpoints) > 0

  # ── network ACL ───────────────────────────────────────────────────────────
  nacl_spec   = lookup(local.spec, "network_acl", {})
  manage_nacl = try(local.nacl_spec.manage_default, false)

  # Inbound/outbound are maps keyed by AWS rule number. Normalise every entry to the
  # same shape here, then emit in ascending rule-number order - keys are strings, so
  # they are zero-padded before sorting or "100" would sort before "50".
  nacl_in_pad = { for n, r in lookup(local.nacl_spec, "ingress", {}) : format("%05d", tonumber(n)) => {
    rule_number = tonumber(n)
    action      = r.action
    protocol    = tostring(r.protocol)
    cidr_block  = r.cidr_block
    from_port   = tonumber(lookup(r, "from_port", 0))
    to_port     = tonumber(lookup(r, "to_port", 0))
  } }
  nacl_eg_pad = { for n, r in lookup(local.nacl_spec, "egress", {}) : format("%05d", tonumber(n)) => {
    rule_number = tonumber(n)
    action      = r.action
    protocol    = tostring(r.protocol)
    cidr_block  = r.cidr_block
    from_port   = tonumber(lookup(r, "from_port", 0))
    to_port     = tonumber(lookup(r, "to_port", 0))
  } }
  nacl_ingress = [for p in sort(keys(local.nacl_in_pad)) : local.nacl_in_pad[p]]
  nacl_egress  = [for p in sort(keys(local.nacl_eg_pad)) : local.nacl_eg_pad[p]]

  # ── private subnets, for the output contract ──────────────────────────────
  private_subnet_keys  = [for k, s in local.subnets : k if s.tier == "private"]
  public_subnet_keys   = [for k, s in local.subnets : k if s.tier == "public"]
  database_subnet_keys = [for k, s in local.subnets : k if s.tier == "database"]
  plan_azs             = distinct([for k, s in local.subnets : s.availability_zone])
}

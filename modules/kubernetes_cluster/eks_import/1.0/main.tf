# ─────────────────────────────────────────────────────────────────────────────
# EKS control plane
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_eks_cluster" "this" {
  name     = local.cluster.name
  version  = local.cluster.version
  role_arn = aws_iam_role.cluster.arn

  # live was created with self-managed addons bootstrap OFF; the arg is ForceNew, so it must match.
  bootstrap_self_managed_addons = false

  enabled_cluster_log_types = length(local.cluster.enabled_log_types) > 0 ? local.cluster.enabled_log_types : null

  vpc_config {
    subnet_ids              = local.cluster.subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = local.cluster.endpoint_private_access
    endpoint_public_access  = local.cluster.endpoint_public_access
    public_access_cidrs     = local.cluster.public_access_cidrs
  }

  kubernetes_network_config {
    service_ipv4_cidr = local.cluster.service_ipv4_cidr
    ip_family         = local.cluster.ip_family
  }

  encryption_config {
    provider {
      # reference the KMS key this module owns, not a pinned copy of its ARN
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  tags = local.cluster.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
  ]
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM roles
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "cluster" {
  name               = local.cluster_role.name
  path               = "/"
  assume_role_policy = local.cluster_role.assume_role_policy
  tags               = local.cluster_role.tags
}

resource "aws_iam_role" "workers" {
  name               = local.workers_role.name
  path               = "/"
  assume_role_policy = local.workers_role.assume_role_policy
  tags               = local.workers_role.tags
}

resource "aws_iam_policy" "elb_sl" {
  name        = local.elb_sl_policy.name
  path        = "/"
  description = local.elb_sl_policy.description
  policy      = local.elb_sl_policy.policy
  tags        = local.elb_sl_policy.tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  for_each   = local.cluster_policy_arns
  role       = aws_iam_role.cluster.name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "workers" {
  for_each   = local.workers_policy_arns
  role       = aws_iam_role.workers.name
  policy_arn = each.value
}

# ─────────────────────────────────────────────────────────────────────────────
# Security groups (rules declared separately below)
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_security_group" "cluster" {
  name        = local.cluster_sg.name
  description = local.cluster_sg.description
  vpc_id      = local.vpc_id
  tags        = local.cluster_sg.tags
}

resource "aws_security_group" "workers" {
  name        = local.workers_sg.name
  description = local.workers_sg.description
  vpc_id      = local.vpc_id
  tags        = local.workers_sg.tags
}

# Legacy aws_security_group_rule (the type live was built with) — imports by a deterministic
# composite id (sgid_type_protocol_from_to_source), which is what we can build offline. The
# newer aws_vpc_security_group_*_rule needs the real sgr- id, which the legacy state never stored.
resource "aws_security_group_rule" "this" {
  for_each = local.sg_rules

  type                     = each.value.type
  protocol                 = each.value.protocol
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  security_group_id        = local.sg_id[each.value.sg]
  cidr_blocks              = try(each.value.cidr_blocks, null)
  source_security_group_id = contains(keys(each.value), "referenced_sg") ? local.sg_id[each.value.referenced_sg] : null
  self                     = try(each.value.self, null)
  description              = each.value.description
}

# ─────────────────────────────────────────────────────────────────────────────
# Self-managed workers: instance profiles + launch templates + ASGs
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_instance_profile" "workers" {
  for_each = local.instance_profiles
  name     = each.value.name
  path     = "/"
  role     = aws_iam_role.workers.name
  tags     = local.cluster.tags
}

# SSH key pair the worker launch templates use (owned here, matching the live cluster module).
resource "aws_key_pair" "nodes" {
  key_name   = local.key_pair.key_name
  public_key = local.key_pair.public_key
  tags       = lookup(local.key_pair, "tags", {})

  # AWS never returns the public key material on read, so import can't populate it and any
  # value shows as an add on this ForceNew field. Ignore it — the key pair is immutable.
  lifecycle {
    ignore_changes = [public_key]
  }
}

resource "aws_launch_template" "workers" {
  for_each = local.launch_templates

  name          = each.value.name
  image_id      = each.value.image_id
  instance_type = each.value.instance_type
  # reference the key pair this module owns, not a pinned copy of its name
  key_name      = aws_key_pair.nodes.key_name
  user_data     = each.value.user_data
  ebs_optimized = "true"

  iam_instance_profile {
    # reference the instance profile this module owns (same key), not a pinned copy of its name
    name = aws_iam_instance_profile.workers[each.key].name
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint          = "enabled"
    http_tokens            = "required"
    http_protocol_ipv6     = "disabled"
    instance_metadata_tags = "disabled"
  }

  network_interfaces {
    associate_public_ip_address = "false"
    delete_on_termination       = "true"
    device_index                = 0
    security_groups             = [aws_security_group.workers.id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = "true"
      encrypted             = "true"
      volume_size           = 100
      volume_type           = "gp3"
    }
  }

  enclave_options {
    enabled = false
  }

  dynamic "tag_specifications" {
    for_each = ["instance", "network-interface", "volume"]
    content {
      resource_type = tag_specifications.value
      tags          = merge(each.value.tags, { Name = each.value.tag_name })
    }
  }

  tags = each.value.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "workers" {
  for_each = local.asgs

  name                      = each.value.name
  min_size                  = each.value.min
  max_size                  = each.value.max
  desired_capacity          = each.value.desired
  vpc_zone_identifier       = each.value.subnets
  health_check_type         = "EC2"
  health_check_grace_period = 300
  default_cooldown          = 300
  suspended_processes       = ["AZRebalance"]
  service_linked_role_arn   = each.value.service_linked_role_arn
  metrics_granularity       = "1Minute"
  wait_for_capacity_timeout = "10m"

  dynamic "launch_template" {
    for_each = each.value.mixed ? [] : [1]
    content {
      id      = aws_launch_template.workers[each.key].id
      version = each.value.lt_version
    }
  }

  dynamic "mixed_instances_policy" {
    for_each = each.value.mixed ? [1] : []
    content {
      instances_distribution {
        on_demand_allocation_strategy            = each.value.instances_distribution.on_demand_allocation_strategy
        on_demand_base_capacity                  = each.value.instances_distribution.on_demand_base_capacity
        on_demand_percentage_above_base_capacity = each.value.instances_distribution.on_demand_percentage_above_base_capacity
        spot_allocation_strategy                 = each.value.instances_distribution.spot_allocation_strategy
      }
      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.workers[each.key].id
          version            = each.value.lt_version
        }
        dynamic "override" {
          for_each = each.value.overrides
          content {
            instance_type = override.value
          }
        }
      }
    }
  }

  dynamic "tag" {
    for_each = each.value.tags
    content {
      key                 = tag.value.key
      value               = tag.value.value
      propagate_at_launch = tag.value.propagate_at_launch
    }
  }

  lifecycle {
    create_before_destroy = true
    # desired_capacity: autoscaler-managed. The rest are Terraform-only client-side knobs
    # (destroy/apply behaviour, wait duration) that the AWS API never returns, so import
    # cannot populate them and they would otherwise show a perpetual no-op in-place update.
    ignore_changes = [
      desired_capacity,
      target_group_arns,
      force_delete,
      force_delete_warm_pool,
      ignore_failed_scaling_activities,
      wait_for_capacity_timeout,
    ]
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# EKS add-ons
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_eks_addon" "this" {
  for_each = local.addons

  cluster_name             = aws_eks_cluster.this.name
  addon_name               = each.value.addon_name
  addon_version            = each.value.addon_version
  configuration_values     = try(each.value.configuration_values, null)
  service_account_role_arn = try(each.value.service_account_role_arn, null)
  tags                     = each.value.tags
}

# ─────────────────────────────────────────────────────────────────────────────
# OIDC provider + secrets KMS key
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_openid_connect_provider" "this" {
  # url argument must carry a scheme; AWS/state stores it without one.
  url             = startswith(local.oidc.url, "https://") ? local.oidc.url : "https://${local.oidc.url}"
  client_id_list  = local.oidc.client_id_list
  thumbprint_list = local.oidc.thumbprint_list
  tags            = local.oidc.tags
}

resource "aws_kms_key" "eks" {
  description              = local.kms.description
  key_usage                = local.kms.key_usage
  customer_master_key_spec = local.kms.customer_master_key_spec
  enable_key_rotation      = local.kms.enable_key_rotation
  policy                   = local.kms.policy
  tags                     = local.kms.tags
}

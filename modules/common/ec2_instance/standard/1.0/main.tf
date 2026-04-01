locals {
  spec     = lookup(var.instance, "spec", {})
  metadata = lookup(var.instance, "metadata", {})
  # Use instance_name directly - guaranteed non-null, can be overridden via spec.name
  # Use try() to safely access spec.name which may not exist
  name = try(var.instance.spec.name, null) != null && try(var.instance.spec.name, "") != "" ? var.instance.spec.name : var.instance_name

  # Network Configuration
  vpc_id            = lookup(local.spec, "vpc_id", null) != null ? local.spec.vpc_id : var.inputs.network_details.attributes.vpc_id
  vpc_cidr          = lookup(local.spec, "vpc_cidr", null) != null ? local.spec.vpc_cidr : var.inputs.network_details.attributes.vpc_cidr_block
  subnet_id_list    = lookup(local.spec, "subnet_id", null)
  subnet_id         = local.subnet_id_list != null && length(local.subnet_id_list) > 0 ? element(local.subnet_id_list, 0) : element(var.inputs.network_details.attributes.private_subnet_ids, 0)
  availability_zone = lookup(local.spec, "availability_zone", null) != null ? local.spec.availability_zone : element(var.inputs.network_details.attributes.availability_zones, 0)

  # Tags
  tags        = lookup(local.spec, "tags", {})
  merged_tags = merge(local.tags, var.environment.cloud_tags)

  # Instance Configuration
  ami_id        = lookup(local.spec, "ami_id", data.aws_ami.amazon_linux.id)
  instance_type = lookup(local.spec, "instance_type", "t3.medium")

  # Security Group Configuration
  create_security_group      = lookup(local.spec, "create_security_group", true)
  security_group_name        = lookup(local.spec, "security_group_name", null) != null ? local.spec.security_group_name : "${local.name}-sg"
  security_group_description = lookup(local.spec, "security_group_description", null) != null ? local.spec.security_group_description : "Security group for EC2 instance ${local.name}"

  # Security Group Rules Configuration
  ingress_rules = lookup(local.spec, "ingress_rules", [])
  egress_rules = lookup(local.spec, "egress_rules", [
    {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow all outbound traffic"
    }
  ])

  # Determine which security groups to use
  vpc_security_group_ids = lookup(local.spec, "vpc_security_group_ids", null) != null ? lookup(local.spec, "vpc_security_group_ids", []) : (
    local.create_security_group ? [aws_security_group.this[0].id] : []
  )

  # Placement Group Configuration
  create_placement_group   = lookup(local.spec, "create_placement_group", false)
  placement_group_name     = lookup(local.spec, "placement_group_name", null) != null ? local.spec.placement_group_name : "${local.name}-pg"
  placement_group_strategy = lookup(local.spec, "placement_group_strategy", "cluster")
  placement_group_id       = lookup(local.spec, "placement_group_id", null)

  # Determine placement group to use
  placement_group = local.placement_group_id != null ? local.placement_group_id : (
    local.create_placement_group ? aws_placement_group.ec2_placement[0].id : null
  )

  # IAM Configuration
  create_iam_instance_profile = lookup(local.spec, "create_iam_instance_profile", true)
  iam_role_name               = lookup(local.spec, "iam_role_name", null) != null ? local.spec.iam_role_name : "${local.name}-role"
  iam_role_description        = lookup(local.spec, "iam_role_description", null) != null ? local.spec.iam_role_description : "IAM role for EC2 instance ${local.name}"
  iam_role_policies_raw       = lookup(local.spec, "iam_role_policies", null)
  iam_role_policies = local.iam_role_policies_raw != null ? local.iam_role_policies_raw : (
    local.create_iam_instance_profile ? {
      SSMManaged = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    } : {}
  )
  iam_instance_profile = lookup(local.spec, "iam_instance_profile", null)

  # Instance Features
  create_eip                  = lookup(local.spec, "create_eip", false)
  associate_public_ip_address = lookup(local.spec, "associate_public_ip_address", false)
  disable_api_stop            = lookup(local.spec, "disable_api_stop", false)
  disable_api_termination     = lookup(local.spec, "disable_api_termination", false)
  hibernation                 = lookup(local.spec, "hibernation", false)
  monitoring                  = lookup(local.spec, "monitoring", true)
  enable_volume_tags          = lookup(local.spec, "enable_volume_tags", true)

  # User Data
  user_data                   = lookup(local.spec, "user_data", null)
  user_data_base64            = lookup(local.spec, "user_data_base64", null)
  user_data_replace_on_change = lookup(local.spec, "user_data_replace_on_change", false)

  # Storage - Default Configurations
  default_cpu_options = {
    core_count       = 2
    threads_per_core = 2
  }

  default_root_block_device = {
    encrypted             = true
    type                  = "gp3" 
    throughput            = 125
    size                  = 30 
    iops                  = 3000
    kms_key_id            = null
    delete_on_termination = true

    tags = local.merged_tags
  }

  default_ebs_block_device = {}

  # Storage - User Overrides
  cpu_options         = lookup(local.spec, "cpu_options", local.default_cpu_options)
  user_root_block_raw = lookup(local.spec, "root_block_device", null)
  root_block_device = local.user_root_block_raw != null ? {
    # Map user-friendly field names to Terraform resource field names
    size                  = lookup(local.user_root_block_raw, "volume_size", lookup(local.user_root_block_raw, "size", null))
    type                  = lookup(local.user_root_block_raw, "volume_type", lookup(local.user_root_block_raw, "type", null))
    encrypted             = lookup(local.user_root_block_raw, "encrypted", null)
    iops                  = lookup(local.user_root_block_raw, "iops", null)
    throughput            = lookup(local.user_root_block_raw, "throughput", null)
    kms_key_id            = lookup(local.user_root_block_raw, "kms_key_id", null)
    delete_on_termination = lookup(local.user_root_block_raw, "delete_on_termination", null)
    tags                  = lookup(local.user_root_block_raw, "tags", null)
  } : local.default_root_block_device
  ebs_volumes = lookup(local.spec, "ebs_volumes", null) != null ? {
    for device_name, config in lookup(local.spec, "ebs_volumes", {}) : device_name => merge(
      {
        device_name           = lookup(config, "device_name", device_name)
        size                  = lookup(config, "volume_size", 10)    # Map volume_size to size for underlying module
        type                  = lookup(config, "volume_type", "gp3") # Map volume_type to type
        throughput            = lookup(config, "throughput", 125)
        iops                  = lookup(config, "iops", 3000)
        encrypted             = lookup(config, "encrypted", true)
        kms_key_id            = lookup(config, "kms_key_id", null)
        delete_on_termination = lookup(config, "delete_on_termination", true)
        tags                  = merge(local.merged_tags, lookup(config, "tags", {}))
      }
    )
  } : local.default_ebs_block_device
}

# Data source for default AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  name_regex  = "^al2023-ami-2023.*-x86_64"
}

# Conditional Placement Group
resource "aws_placement_group" "ec2_placement" {
  count = local.create_placement_group ? 1 : 0

  name     = local.placement_group_name
  strategy = local.placement_group_strategy

  tags = local.merged_tags
}

# Conditional Security Group
resource "aws_security_group" "this" {
  count = local.create_security_group ? 1 : 0

  name_prefix = "${local.security_group_name}-"
  description = local.security_group_description
  vpc_id      = local.vpc_id

  tags = merge(
    local.merged_tags,
    {
      Name = local.security_group_name
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group Ingress Rules
resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = local.create_security_group ? { for idx, rule in local.ingress_rules : idx => rule } : {}

  security_group_id = aws_security_group.this[0].id

  ip_protocol = lookup(each.value, "ip_protocol", "tcp")
  from_port   = lookup(each.value, "from_port", null)
  to_port     = lookup(each.value, "to_port", null)

  cidr_ipv4                    = lookup(each.value, "cidr_ipv4", null)
  cidr_ipv6                    = lookup(each.value, "cidr_ipv6", null)
  referenced_security_group_id = lookup(each.value, "referenced_security_group_id", null)

  description = lookup(each.value, "description", null)

  tags = merge(
    local.merged_tags,
    {
      Name = "${local.security_group_name}-ingress-${each.key}"
    }
  )
}

# Security Group Egress Rules
resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = local.create_security_group ? { for idx, rule in local.egress_rules : idx => rule } : {}

  security_group_id = aws_security_group.this[0].id

  ip_protocol = lookup(each.value, "ip_protocol", "tcp")
  from_port   = lookup(each.value, "from_port", null)
  to_port     = lookup(each.value, "to_port", null)

  cidr_ipv4                    = lookup(each.value, "cidr_ipv4", null)
  cidr_ipv6                    = lookup(each.value, "cidr_ipv6", null)
  referenced_security_group_id = lookup(each.value, "referenced_security_group_id", null)

  description = lookup(each.value, "description", null)

  tags = merge(
    local.merged_tags,
    {
      Name = "${local.security_group_name}-egress-${each.key}"
    }
  )
}

# EC2 Instance Module
module "ec2_instance" {
  source = "./terraform-aws-ec2-instance"

  name = local.name

  # Instance Configuration
  ami                    = local.ami_id
  instance_type          = local.instance_type
  availability_zone      = local.availability_zone
  subnet_id              = local.subnet_id
  vpc_security_group_ids = local.vpc_security_group_ids

  # Placement Group
  placement_group = local.placement_group

  # IAM
  create_iam_instance_profile = local.create_iam_instance_profile
  iam_role_name               = local.iam_role_name
  iam_role_description        = local.iam_role_description
  iam_role_policies           = local.iam_role_policies
  iam_instance_profile        = local.iam_instance_profile

  # Network Features
  associate_public_ip_address = local.associate_public_ip_address

  # Instance Features
  disable_api_stop        = local.disable_api_stop
  disable_api_termination = local.disable_api_termination
  hibernation             = local.hibernation
  monitoring              = local.monitoring
  enable_volume_tags      = local.enable_volume_tags

  # User Data
  user_data_base64            = local.user_data_base64 != null ? local.user_data_base64 : (local.user_data != null && local.user_data != "" ? base64encode(local.user_data) : null)
  user_data_replace_on_change = local.user_data_replace_on_change

  # Storage
  cpu_options       = local.cpu_options
  root_block_device = local.root_block_device
  ebs_volumes       = local.ebs_volumes

  # Tags
  tags = local.merged_tags
}

# Conditional Elastic IP
resource "aws_eip" "instance_eip" {
  count = local.create_eip ? 1 : 0

  instance = module.ec2_instance.id
  domain   = "vpc"

  tags = merge(
    local.merged_tags,
    {
      Name = "${local.name}-eip"
    }
  )

  depends_on = [module.ec2_instance]
}

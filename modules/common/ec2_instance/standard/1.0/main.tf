locals {
  spec        = lookup(var.instance, "spec", {})
  metadata    = lookup(var.instance, "metadata", {})
  name        = lookup(local.metadata, "name", module.name.name)

  # Network Configuration
  vpc_id    = lookup(local.spec, "vpc_id", var.inputs.network_details.attributes.vpc_id)
  vpc_cidr  = lookup(local.spec, "vpc_cidr", var.inputs.network_details.attributes.vpc_cidr_block)
  subnet_id = lookup(local.spec, "subnet_id", var.inputs.network_details.attributes.private_subnet_ids)
  availability_zone = lookup(local.spec, "availability_zone", element(var.inputs.network_details.attributes.availability_zones, 0))

  # Tags
  tags        = lookup(local.spec, "tags", {})
  merged_tags = merge(local.tags, var.environment.cloud_tags)

  # Instance Configuration
  ami_id        = lookup(local.spec, "ami_id", data.aws_ami.amazon_linux.id)
  instance_type = lookup(local.spec, "instance_type", "t3.medium")

  # Security Group Configuration
  create_security_group = lookup(local.spec, "create_security_group", true)
  security_group_name   = lookup(local.spec, "security_group_name", "${local.name}-sg")
  security_group_description = lookup(local.spec, "security_group_description", "Security group for EC2 instance ${local.name}")

  # Determine which security groups to use
  vpc_security_group_ids = lookup(local.spec, "vpc_security_group_ids", null) != null ? lookup(local.spec, "vpc_security_group_ids", []) : (
    local.create_security_group ? [module.security_group[0].security_group_id] : []
  )

  # Placement Group Configuration
  create_placement_group   = lookup(local.spec, "create_placement_group", false)
  placement_group_name     = lookup(local.spec, "placement_group_name", "${local.name}-pg")
  placement_group_strategy = lookup(local.spec, "placement_group_strategy", "cluster")
  placement_group_id       = lookup(local.spec, "placement_group_id", null)

  # Determine placement group to use
  placement_group = local.placement_group_id != null ? local.placement_group_id : (
    local.create_placement_group ? aws_placement_group.ec2_placement[0].id : null
  )

  # IAM Configuration
  create_iam_instance_profile = lookup(local.spec, "create_iam_instance_profile", true)
  iam_role_name               = lookup(local.spec, "iam_role_name", "${local.name}-role")
  iam_role_description        = lookup(local.spec, "iam_role_description", "IAM role for EC2 instance ${local.name}")
  iam_role_policies = lookup(local.spec, "iam_role_policies", {
    SSMManaged = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  })
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
  user_data                   = lookup(local.spec, "user_data", "")
  user_data_base64            = lookup(local.spec, "user_data_base64", null)
  user_data_replace_on_change = lookup(local.spec, "user_data_replace_on_change", false)

  # Storage - Default Configurations
  default_cpu_options = {
    core_count       = 2
    threads_per_core = 2
  }

  default_root_block_device = [{
    encrypted             = true
    volume_type           = "gp3"
    throughput            = 125
    volume_size           = 30
    iops                  = 3000
    delete_on_termination = true
    tags                  = local.merged_tags
  }]

  default_ebs_block_device = []

  # Storage - User Overrides
  cpu_options       = lookup(local.spec, "cpu_options", local.default_cpu_options)
  root_block_device = lookup(local.spec, "root_block_device", null) != null ? [lookup(local.spec, "root_block_device", {})] : local.default_root_block_device
  ebs_block_device  = lookup(local.spec, "ebs_volumes", null) != null ? [
    for device_name, config in lookup(local.spec, "ebs_volumes", {}) : merge(
      {
        device_name           = lookup(config, "device_name", device_name)
        volume_size           = lookup(config, "volume_size", 10)
        volume_type           = lookup(config, "volume_type", "gp3")
        throughput            = lookup(config, "throughput", 125)
        iops                  = lookup(config, "iops", 3000)
        encrypted             = lookup(config, "encrypted", true)
        kms_key_id            = lookup(config, "kms_key_id", null)
        delete_on_termination = lookup(config, "delete_on_termination", true)
        tags                  = merge(local.merged_tags, lookup(config, "tags", {}))
      }
    )
  ] : local.default_ebs_block_device
}

# Data source for default AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  name_regex  = "^al2023-ami-2023.*-x86_64"
}

# Name generation module
module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  is_k8s          = false
  globally_unique = false
  resource_type   = "ec2_instance"
  resource_name   = var.instance_name
  environment     = var.environment
  limit           = 45
}

# Conditional Placement Group
resource "aws_placement_group" "ec2_placement" {
  count = local.create_placement_group ? 1 : 0

  name     = local.placement_group_name
  strategy = local.placement_group_strategy

  tags = local.merged_tags
}

# Conditional Security Group
module "security_group" {
  count   = local.create_security_group ? 1 : 0
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = local.security_group_name
  description = local.security_group_description
  vpc_id      = local.vpc_id

  ingress_cidr_blocks = lookup(local.spec, "ingress_cidr_blocks", [local.vpc_cidr])
  ingress_rules       = lookup(local.spec, "ingress_rules", [])
  egress_cidr_blocks  = lookup(local.spec, "egress_cidr_blocks", ["0.0.0.0/0"])
  egress_rules        = lookup(local.spec, "egress_rules", ["all-all"])

  tags = local.merged_tags
}

# EC2 Instance Module
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

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
  user_data_base64            = local.user_data_base64 != null ? local.user_data_base64 : (local.user_data != "" ? base64encode(local.user_data) : null)
  user_data_replace_on_change = local.user_data_replace_on_change

  # Storage
  cpu_options       = local.cpu_options
  root_block_device = local.root_block_device
  ebs_block_device  = local.ebs_block_device

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

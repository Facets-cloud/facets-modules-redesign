locals {
  output_attributes = {
    instance_id       = module.ec2_instance.id
    instance_arn      = module.ec2_instance.arn
    public_ip         = local.create_eip ? aws_eip.instance_eip[0].public_ip : module.ec2_instance.public_ip
    private_ip        = module.ec2_instance.private_ip
    private_dns       = module.ec2_instance.private_dns
    public_dns        = module.ec2_instance.public_dns
    iam_role_arn      = local.create_iam_instance_profile ? module.ec2_instance.iam_role_arn : null
    iam_role_name     = local.create_iam_instance_profile ? module.ec2_instance.iam_role_name : null
    iam_instance_profile_arn  = local.create_iam_instance_profile ? module.ec2_instance.iam_instance_profile_arn : null
    iam_instance_profile_name = local.create_iam_instance_profile ? module.ec2_instance.iam_instance_profile_name : null
    security_group_id = local.create_security_group ? module.security_group[0].security_group_id : null
    availability_zone = module.ec2_instance.availability_zone
    subnet_id         = module.ec2_instance.subnet_id
    placement_group   = local.placement_group
    eip_id            = local.create_eip ? aws_eip.instance_eip[0].id : null
    eip_allocation_id = local.create_eip ? aws_eip.instance_eip[0].allocation_id : null
  }

  output_interfaces = {}
}

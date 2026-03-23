locals {
  output_attributes = {
    instance_id       = module.ec2_instance.id
    public_ip         = module.ec2_instance.public_ip
    private_ip        = module.ec2_instance.private_ip
    iam_role_arn      = module.ec2_instance.iam_role_arn
    iam_role_name     = module.ec2_instance.iam_role_name
    security_group_id = module.security_group.security_group_id
    availability_zone = module.ec2_instance.availability_zone
    subnet_id         = module.ec2_instance.subnet_id
  }

  output_interfaces = {}
}
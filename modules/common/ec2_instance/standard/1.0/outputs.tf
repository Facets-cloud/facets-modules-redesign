locals {
  output_attributes = {
    instance_id       = module.ec2_instance.id
    public_ip         = module.ec2_instance.public_ip
    private_ip        = module.ec2_instance.private_ip
    iam_role_arn      = module.ec2_instance.iam_role_arn
    iam_role_name     = module.ec2_instance.iam_role_name
    security_group_id = local.create_security_group ? aws_security_group.this[0].id : null
    availability_zone = module.ec2_instance.availability_zone
    subnet_id         = local.subnet_id
    ssh_key_name      = local.enable_ssh ? aws_key_pair.this[0].key_name : null
    ssh_private_key   = local.enable_ssh ? tls_private_key.this[0].private_key_pem : null
  }

  output_interfaces = {}
}
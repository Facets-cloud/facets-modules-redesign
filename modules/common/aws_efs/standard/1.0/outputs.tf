locals {
  output_interfaces = {}
  output_attributes = {
    file_system_id    = aws_efs_file_system.efs-csi-driver.id
    security_group_id = aws_security_group.efs-csi-driver.id
  }
}

locals {
  output_attributes = {
    file_system_id    = aws_efs_file_system.main.id
    security_group_id = try(values(aws_efs_mount_target.main)[0].security_groups[0], null)
  }
  output_interfaces = {}
}

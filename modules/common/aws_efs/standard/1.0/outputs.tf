locals {
  output_attributes = {
    file_system_id    = aws_efs_file_system.efs-csi-driver.id
    arn               = aws_efs_file_system.efs-csi-driver.arn
    dns_name          = aws_efs_file_system.efs-csi-driver.dns_name
    security_group_id = local.create_security_group ? aws_security_group.efs-csi-driver[0].id : ""
    mount_target_ids  = [for k, m in aws_efs_mount_target.efs-csi-driver : m.id]
    mount_target_dns  = [for k, m in aws_efs_mount_target.efs-csi-driver : m.dns_name]
    access_point_ids  = { for k, a in aws_efs_access_point.this : k => a.id }
    access_point_arns = { for k, a in aws_efs_access_point.this : k => a.arn }
  }
  output_interfaces = {}
}

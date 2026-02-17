locals {
  output_attributes = {
    efs_file_system_id  = aws_efs_file_system.efs_csi_driver.id
    efs_file_system_arn = aws_efs_file_system.efs_csi_driver.arn
    iam_role_arn        = aws_iam_role.efs_csi_driver.arn
    storage_class_name  = "efs-sc"
    helm_release_id     = helm_release.efs_csi_driver.id
    secrets             = []
  }

  output_interfaces = {}
}

output "default" {
  value = {
    attributes = local.output_attributes
    interfaces = local.output_interfaces
  }
}

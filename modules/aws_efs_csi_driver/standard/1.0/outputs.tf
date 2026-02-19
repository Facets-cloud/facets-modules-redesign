locals {
  output_attributes = {
    iam_role_arn    = module.irsa.iam_role_arn
    helm_release_id = helm_release.efs_csi_driver.id
    secrets         = []
  }

  output_interfaces = {}
}


locals {
  output_attributes = {
    iam_role_arn    = module.irsa.iam_role_arn
    helm_release_id = local.manage_helm_release ? helm_release.efs_csi_driver[0].id : null
    secrets         = []
  }

  output_interfaces = {}
}


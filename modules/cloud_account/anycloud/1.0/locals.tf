# Anycloud account: fetch creds only for the SELECTED cloud (count-gated).
# Data sources are NOT executed during validate/dry-run — only at apply.
locals {
  is_aws = var.instance.spec.cloud_provider == "AWS"
  is_gcp = var.instance.spec.cloud_provider == "GCP"
}

data "external" "aws_fetch_cloud_secret" {
  count = local.is_aws ? 1 : 0
  program = [
    "python3",
    "/sources/primary/capillary-cloud-tf/tfmain/scripts/cloudaccount-fetch-secret/secret-fetcher.py",
    var.instance.spec.aws_cloud_account,
    "AWS"
  ]
}

data "external" "gcp_fetch_cloud_secret" {
  count = local.is_gcp ? 1 : 0
  program = [
    "python3",
    "/sources/primary/capillary-cloud-tf/tfmain/scripts/cloudaccount-fetch-secret/secret-fetcher.py",
    var.instance.spec.gcp_cloud_account,
    "GCP"
  ]
}

data "external" "gcp_fetch_cloud_secret" {
  program = [
    "python3",
    "${path.module}/secret-fetcher.py",
    var.instance.spec.cloud_account,
    "GCP"
  ]
}

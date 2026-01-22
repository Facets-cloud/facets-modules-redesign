resource "kubernetes_priority_class_v1" "ecr_token_refresher" {
  metadata {
    name = "${local.name}-ecr-token-refresher"
  }

  value          = 1000000000
  global_default = false
  description    = "Priority class for ECR token refresher pods for ${local.name}"
}

resource "helm_release" "prometheus_recording_rules_helm" {
  name            = "recording-rules-${var.instance_name}"
  chart           = "${path.module}/any-resource-0.1.0.tgz"
  repository      = "kiwigrid"
  namespace       = var.environment.namespace
  version         = "0.1.0"
  cleanup_on_fail = true
  timeout         = 720
  atomic          = false
  values = [
    <<EOF
prometheusId: ${try(var.inputs.prometheus_details.attributes.helm_release_id, "")}
EOF 
    , local.helm_values_yaml
  ]
}
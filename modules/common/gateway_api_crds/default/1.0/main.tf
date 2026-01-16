# Install Kubernetes Gateway API CRDs
# Gateway API CRDs are installed via kubectl apply from the official release

locals {
  gateway_api_version = lookup(var.instance.spec, "gateway_api_version", "v1.2.0")
  crds_url            = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${local.gateway_api_version}/standard-install.yaml"
}

# Install Gateway API CRDs using kubectl apply
resource "null_resource" "gateway_api_crds" {
  triggers = {
    version = local.gateway_api_version
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${local.crds_url}"
  }
}

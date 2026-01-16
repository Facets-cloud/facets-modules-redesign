# Install Kubernetes Gateway API CRDs
# Gateway API CRDs are installed via kubectl apply from the official release

locals {
  gateway_api_version = lookup(var.instance.spec, "gateway_api_version", "v1.2.0")
  crds_url            = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${local.gateway_api_version}/standard-install.yaml"
}

# Fetch Gateway API CRDs manifest
data "http" "gateway_api_crds" {
  url = local.crds_url
}

# Install Gateway API CRDs using null_resource with kubectl
resource "null_resource" "gateway_api_crds" {
  triggers = {
    version = local.gateway_api_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f ${local.crds_url}
    EOT
  }
}

# Alternative: Use experimental CRDs if needed (includes TCPRoute, TLSRoute, etc.)
resource "null_resource" "gateway_api_experimental_crds" {
  count = lookup(var.instance.spec, "install_experimental", false) ? 1 : 0

  triggers = {
    version = local.gateway_api_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${local.gateway_api_version}/experimental-install.yaml
    EOT
  }

  depends_on = [null_resource.gateway_api_crds]
}

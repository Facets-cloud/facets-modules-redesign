# Install Traefik CRDs using the dedicated traefik-crds helm chart
resource "helm_release" "traefik_crds" {
  name             = "${var.instance_name}-traefik-crds"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik-crds"
  namespace        = lookup(var.instance.spec, "namespace", "traefik")
  create_namespace = lookup(var.instance.spec, "create_namespace", true)

  # Wait for CRDs to be fully established
  wait = true
}

locals {
  # @facets/service (best-effort for a VM-backed service — the workload is GCE VMs, not k8s pods).
  output_attributes = {
    namespace           = local.gcp_project
    resource_name       = local.service_name
    resource_type       = local.spec.type
    service_name        = local.service_name
    service_account_arn = local.sa_email
    selector_labels     = "service=${local.service_name}"

    # VM-backed extras.
    replica_names = [for k, v in google_compute_instance.vm : v.name]
    internal_ips  = [for k, v in google_compute_instance.vm : v.network_interface[0].network_ip]
    self_links    = [for k, v in google_compute_instance.vm : v.self_link]
    secrets       = []
  }

  output_interfaces = {}
}

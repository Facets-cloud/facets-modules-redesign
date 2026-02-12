locals {
  output_attributes = {
    network_id           = ovh_cloud_project_network_private.network.id
    network_name         = ovh_cloud_project_network_private.network.name
    network_cidr         = var.instance.spec.network_cidr
    openstack_network_id = tolist(ovh_cloud_project_network_private.network.regions_attributes[*].openstackid)[0]
    region               = local.region
    project_id           = data.ovh_cloud_project.project.service_name

    # K8s subnet outputs
    k8s_subnet_id   = ovh_cloud_project_network_private_subnet.k8s_subnet.id
    k8s_subnet_cidr = local.k8s_subnet_cidr
    k8s_gateway_ip  = ovh_cloud_project_network_private_subnet.k8s_subnet.gateway_ip
    gateway_id      = ovh_cloud_project_gateway.gateway.id

    # Database subnet outputs
    db_subnet_id   = ovh_cloud_project_network_private_subnet.db_subnet.id
    db_subnet_cidr = local.db_subnet_cidr

    # Load balancer subnet outputs
    lb_subnet_id   = ovh_cloud_project_network_private_subnet.lb_subnet.id
    lb_subnet_cidr = local.lb_subnet_cidr
  }
  output_interfaces = {
  }
}
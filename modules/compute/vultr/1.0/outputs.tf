locals {
  output_attributes = {
    instance_ids      = [for i in vultr_instance.this : i.id]
    instance_id       = length(vultr_instance.this) > 0 ? vultr_instance.this[0].id : ""
    main_ips          = [for i in vultr_instance.this : i.main_ip]
    main_ip           = length(vultr_instance.this) > 0 ? vultr_instance.this[0].main_ip : ""
    internal_ips      = [for i in vultr_instance.this : i.internal_ip]
    region            = local.region
    plan              = var.instance.spec.sizing.plan
    firewall_group_id = var.instance.spec.firewall.manage ? vultr_firewall_group.this[0].id : ""
  }

  output_interfaces = {
    ssh = {
      host     = length(vultr_instance.this) > 0 ? vultr_instance.this[0].main_ip : ""
      port     = "22"
      username = "root"
      password = length(vultr_instance.this) > 0 ? vultr_instance.this[0].default_password : ""
      secrets  = ["password"]
    }
  }
}

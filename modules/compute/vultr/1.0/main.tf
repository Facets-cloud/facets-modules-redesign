# Vultr Compute Instances Module
# Provisions one or more identical Vultr cloud compute instances (count-scaled),
# with optional SSH keys, startup script, VPC attach, and managed firewall.

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 32
  resource_name = var.instance_name
  resource_type = "compute"
}

locals {
  region     = coalesce(try(var.instance.spec.region, null), var.inputs.vultr_cloud_account.attributes.region)
  vpc_ids    = (var.instance.spec.networking.attach_vpc && var.inputs.network != null) ? [var.inputs.network.attributes.vpc_id] : null
  has_script = length(trimspace(var.instance.spec.access.startup_script)) > 0
}

resource "vultr_ssh_key" "this" {
  for_each = { for idx, k in var.instance.spec.access.ssh_public_keys : tostring(idx) => k }
  name     = "${module.name.name}-${each.key}"
  ssh_key  = each.value
}

resource "vultr_startup_script" "this" {
  count  = local.has_script ? 1 : 0
  name   = module.name.name
  script = base64encode(var.instance.spec.access.startup_script)
}

resource "vultr_firewall_group" "this" {
  count       = var.instance.spec.firewall.manage ? 1 : 0
  description = module.name.name
}

resource "vultr_firewall_rule" "this" {
  for_each          = var.instance.spec.firewall.manage ? var.instance.spec.firewall.open_ports : {}
  firewall_group_id = vultr_firewall_group.this[0].id
  protocol          = each.value.protocol
  ip_type           = "v4"
  subnet            = split("/", each.value.source)[0]
  subnet_size       = tonumber(split("/", each.value.source)[1])
  port              = each.value.port
}

resource "vultr_instance" "this" {
  count             = var.instance.spec.sizing.count
  region            = local.region
  plan              = var.instance.spec.sizing.plan
  os_id             = var.instance.spec.image.os_id
  label             = "${module.name.name}-${count.index}"
  hostname          = "${module.name.name}-${count.index}"
  enable_ipv6       = var.instance.spec.networking.enable_ipv6
  vpc_ids           = local.vpc_ids
  ssh_key_ids       = [for k in vultr_ssh_key.this : k.id]
  script_id         = local.has_script ? vultr_startup_script.this[0].id : null
  firewall_group_id = var.instance.spec.firewall.manage ? vultr_firewall_group.this[0].id : null
  activation_email  = false
}

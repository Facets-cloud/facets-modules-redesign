locals {
  output_attributes = {
    lb_id  = vultr_load_balancer.this.id
    status = vultr_load_balancer.this.status
    ipv4   = vultr_load_balancer.this.ipv4
    ipv6   = vultr_load_balancer.this.ipv6
  }

  output_interfaces = {
    frontend = {
      host    = vultr_load_balancer.this.ipv4
      ipv6    = vultr_load_balancer.this.ipv6
      secrets = []
    }
  }
}

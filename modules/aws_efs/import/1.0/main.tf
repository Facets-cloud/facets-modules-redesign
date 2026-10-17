# EFS file system (imported; attributes from live)
resource "aws_efs_file_system" "main" {
  creation_token   = local.fs.creation_token
  encrypted        = local.fs.encrypted
  kms_key_id       = local.fs.kms_key_id
  performance_mode = local.fs.performance_mode
  throughput_mode  = local.fs.throughput_mode

  tags = lookup(local.fs, "tags", {})

  # CP-managed tags (facetsclusterid/Name) are injected by the control plane, not owned here.
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags, tags_all]
  }
}

# Security group the mount targets use (owned here, matching the live EFS module).
resource "aws_security_group" "agent" {
  name        = local.sg.name
  description = local.sg.description
  vpc_id      = local.sg.vpc_id
  tags        = lookup(local.sg, "tags", {})

  dynamic "ingress" {
    for_each = lookup(local.sg, "ingress", [])
    content {
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = lookup(ingress.value, "cidr_blocks", [])
      ipv6_cidr_blocks = lookup(ingress.value, "ipv6_cidr_blocks", [])
      prefix_list_ids  = lookup(ingress.value, "prefix_list_ids", [])
      security_groups  = lookup(ingress.value, "security_groups", [])
      self             = lookup(ingress.value, "self", false)
      description      = lookup(ingress.value, "description", null)
    }
  }
  dynamic "egress" {
    for_each = lookup(local.sg, "egress", [])
    content {
      from_port        = egress.value.from_port
      to_port          = egress.value.to_port
      protocol         = egress.value.protocol
      cidr_blocks      = lookup(egress.value, "cidr_blocks", [])
      ipv6_cidr_blocks = lookup(egress.value, "ipv6_cidr_blocks", [])
      prefix_list_ids  = lookup(egress.value, "prefix_list_ids", [])
      security_groups  = lookup(egress.value, "security_groups", [])
      self             = lookup(egress.value, "self", false)
      description      = lookup(egress.value, "description", null)
    }
  }

  # CP-managed tags are injected by the control plane, not owned here — adopt live tags as-is.
  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

# Mount targets (keyed by live subnet id; reference the SG this module owns)
resource "aws_efs_mount_target" "main" {
  for_each = local.mount_targets

  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = each.value.subnet_id
  security_groups = [aws_security_group.agent.id]
}

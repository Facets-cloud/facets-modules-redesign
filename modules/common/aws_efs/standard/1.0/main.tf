# AWS EFS — adoption-capable.
#
# Reworked from the greenfield module. Six things it did that an adoption cannot survive:
#
#  1. MOUNT TARGETS were `count = length(private_subnets)` over the wired network. Hiver's live mount
#     targets sit in EIGHT subnets, and THREE of those are not among the network module's private
#     subnets at all — so a derived set plans the wrong mount targets, and a mount target is what a
#     pod actually connects to. They are now an explicit map, keyed per entry with its own import id.
#  2. It CREATED A SECURITY GROUP unconditionally. Every live filesystem already has one (3 distinct
#     groups, one shared by 4 filesystems), so creating another is both waste and a live change to
#     the mount targets. Gated on adoption and referenced through the entry instead.
#  3. The Name tag came from module.name, so adopting would rewrite the live Name on every one.
#  4. `creation_token` is ForceNew and AWS assigns it at creation — unset, terraform plans a REPLACE
#     of a filesystem holding 22 GB of production data.
#  5. ACCESS POINTS were not modelled at all; 3 filesystems have one.
#  6. The BACKUP POLICY was not modelled; it is a separate resource, enabled on 5 of 6.
#
# `prevent_destroy` is kept: this is stateful storage.
locals {
  spec          = lookup(var.instance, "spec", {})
  metadata_name = lookup(lookup(var.instance, "metadata", {}), "name", "")
  instance_name = length(local.metadata_name) > 0 ? local.metadata_name : var.instance_name

  vpc_id          = var.inputs.network_details.attributes.vpc_id
  vpc_cidr        = var.inputs.network_details.attributes.vpc_cidr_block
  private_subnets = var.inputs.network_details.attributes.private_subnet_ids

  imports = lookup(local.spec, "imports", {})
  adopt   = lookup(local.imports, "import_existing", false)

  # The live Name tag is used verbatim when adopting; a generated one would rewrite it.
  import_name = lookup(local.imports, "name", null)
  fs_name = local.adopt ? (local.import_name != null ? local.import_name : "") : (
    local.import_name != null && local.import_name != "" ? local.import_name : module.name.name
  )

  mount_targets = lookup(local.spec, "mount_targets", {})
  access_points = lookup(local.spec, "access_points", {})

  # A new filesystem still gets one mount target per private subnet, so greenfield behaviour is
  # unchanged when the map is empty.
  derived_mount_targets = {
    for idx, sn in local.private_subnets : "subnet-${idx}" => { subnet_id = sn }
  }
  effective_mount_targets = length(local.mount_targets) > 0 ? local.mount_targets : (
    local.adopt ? {} : local.derived_mount_targets
  )

  # Only create a security group when building AND no entry supplies one.
  entry_sgs             = flatten([for k, v in local.effective_mount_targets : lookup(v, "security_group_ids", [])])
  create_security_group = !local.adopt && length(local.entry_sgs) == 0

  inject_env_tags = lookup(local.spec, "inject_env_tags", !local.adopt)
  base_tags       = merge(local.fs_name != "" ? { Name = local.fs_name } : {}, lookup(local.spec, "tags", {}))
  tags            = local.inject_env_tags ? merge(local.base_tags, var.environment.cloud_tags) : local.base_tags

  backup_enabled = lookup(local.spec, "backup_policy_enabled", null)
  fs_policy      = lookup(local.spec, "file_system_policy_json", null)
}

module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 64
  globally_unique = true
  resource_name   = local.instance_name
  resource_type   = "aws_efs"
  is_k8s          = false
}

resource "aws_efs_file_system" "efs-csi-driver" {
  tags = local.tags

  # ForceNew, and AWS assigns it at creation. Emitting a different one plans destroy+create of
  # stateful storage.
  creation_token                  = lookup(local.spec, "creation_token", null)
  encrypted                       = lookup(local.spec, "encrypted", true)
  kms_key_id                      = lookup(local.spec, "kms_key_id", null)
  performance_mode                = lookup(local.spec, "performance_mode", null)
  availability_zone_name          = lookup(local.spec, "availability_zone_name", null)
  provisioned_throughput_in_mibps = lookup(local.spec, "provisioned_throughput_in_mibps", null)
  throughput_mode                 = lookup(local.spec, "throughput_mode", null)

  dynamic "lifecycle_policy" {
    for_each = lookup(lookup(local.spec, "lifecycle_policy", {}), "transition_to_ia", null) != null ? [1] : []
    content {
      transition_to_ia = local.spec.lifecycle_policy.transition_to_ia
    }
  }

  dynamic "lifecycle_policy" {
    for_each = lookup(lookup(local.spec, "lifecycle_policy", {}), "transition_to_primary_storage_class", null) != null ? [1] : []
    content {
      transition_to_primary_storage_class = local.spec.lifecycle_policy.transition_to_primary_storage_class
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Only for a NEW filesystem. An adopted one already has its groups, shared with others.
resource "aws_security_group" "efs-csi-driver" {
  count = local.create_security_group ? 1 : 0
  name  = module.name.name
  ingress {
    from_port   = 2049
    protocol    = "TCP"
    to_port     = 2049
    cidr_blocks = [local.vpc_cidr]
    description = "Inbound Access to the EFS filesystem ${local.fs_name}"
  }
  vpc_id = local.vpc_id
}

resource "aws_efs_mount_target" "efs-csi-driver" {
  for_each = local.effective_mount_targets

  file_system_id = aws_efs_file_system.efs-csi-driver.id
  subnet_id      = each.value.subnet_id
  ip_address     = lookup(each.value, "ip_address", null)
  security_groups = (length(lookup(each.value, "security_group_ids", [])) > 0
    ? each.value.security_group_ids
  : (local.create_security_group ? [aws_security_group.efs-csi-driver[0].id] : null))
}

resource "aws_efs_access_point" "this" {
  for_each = local.access_points

  file_system_id = aws_efs_file_system.efs-csi-driver.id
  tags           = lookup(each.value, "tags", {})

  dynamic "root_directory" {
    for_each = lookup(each.value, "root_directory_path", null) != null ? [1] : []
    content {
      path = each.value.root_directory_path
      dynamic "creation_info" {
        for_each = length(lookup(each.value, "creation_info", {})) > 0 ? [1] : []
        content {
          owner_uid   = each.value.creation_info.owner_uid
          owner_gid   = each.value.creation_info.owner_gid
          permissions = each.value.creation_info.permissions
        }
      }
    }
  }

  dynamic "posix_user" {
    for_each = length(lookup(each.value, "posix_user", {})) > 0 ? [1] : []
    content {
      uid            = each.value.posix_user.uid
      gid            = each.value.posix_user.gid
      secondary_gids = lookup(each.value.posix_user, "secondary_gids", null)
    }
  }
}

# A separate resource: AWS enables it by default on a new filesystem, so an unmanaged live policy
# is the norm rather than the exception.
resource "aws_efs_backup_policy" "this" {
  count          = local.backup_enabled == null ? 0 : 1
  file_system_id = aws_efs_file_system.efs-csi-driver.id
  backup_policy {
    status = local.backup_enabled ? "ENABLED" : "DISABLED"
  }
}

resource "aws_efs_file_system_policy" "this" {
  count          = local.fs_policy == null || local.fs_policy == "" ? 0 : 1
  file_system_id = aws_efs_file_system.efs-csi-driver.id
  policy         = local.fs_policy
}

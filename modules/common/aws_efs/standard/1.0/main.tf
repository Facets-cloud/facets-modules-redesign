locals {
  spec          = lookup(var.instance, "spec", {})
  metadata_name = lookup(lookup(var.instance, "metadata", {}), "name", module.name.name)
  instance_name = length(local.metadata_name) > 0 ? local.metadata_name : var.instance_name

  vpc_id          = var.inputs.network_details.attributes.vpc_id
  vpc_cidr        = var.inputs.network_details.attributes.vpc_cidr_block
  private_subnets = var.inputs.network_details.attributes.private_subnet_ids
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
  tags = merge({
    Name = module.name.name
  }, lookup(local.spec, "tags", {}), var.environment.cloud_tags)

  creation_token                  = lookup(local.spec, "creation_token", null)
  encrypted                       = lookup(local.spec, "encrypted", true)
  kms_key_id                      = lookup(local.spec, "kms_key_id", null)
  performance_mode                = lookup(local.spec, "performance_mode", null)
  availability_zone_name          = lookup(local.spec, "availability_zone_name", null)
  provisioned_throughput_in_mibps = lookup(local.spec, "provisioned_throughput_in_mibps", null)
  throughput_mode                 = lookup(local.spec, "throughput_mode", null)

  dynamic "lifecycle_policy" {
    for_each = lookup(local.spec, "lifecycle_policy", {})
    content {
      transition_to_ia                    = lookup(lifecycle_policy.value, "transition_to_ia", null)
      transition_to_primary_storage_class = lookup(lifecycle_policy.value, "transition_to_primary_storage_class", null)
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_security_group" "efs-csi-driver" {
  name = module.name.name
  ingress {
    from_port   = 2049
    protocol    = "TCP"
    to_port     = 2049
    cidr_blocks = [local.vpc_cidr]
    description = "Inbound Access to the EFS filesystem ${module.name.name}"
  }
  vpc_id = local.vpc_id
}

resource "aws_efs_mount_target" "efs-csi-driver" {
  count           = length(local.private_subnets)
  file_system_id  = aws_efs_file_system.efs-csi-driver.id
  subnet_id       = length(local.private_subnets) > 0 ? local.private_subnets[count.index] : ""
  security_groups = [aws_security_group.efs-csi-driver.id]
}

resource "kubernetes_storage_class" "efs-csi-drive-sc" {
  metadata {
    name = local.instance_name
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }
  storage_provisioner = "efs.csi.aws.com"
  mount_options = [
    "tls",
    "iam"
  ]
  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.efs-csi-driver.id
    directoryPerms   = "700"
  }
  reclaim_policy      = "Delete"
  volume_binding_mode = "Immediate"
}

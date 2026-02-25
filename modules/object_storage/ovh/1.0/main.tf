# OVH Object Storage Container Module
# Creates an S3-compatible object storage container in OVH Cloud

locals {
  # Container name with environment prefix for uniqueness
  container_name = "${var.environment.unique_name}-${var.instance_name}"

  # Default region (can be made configurable if needed)
  region = "GRA"
}

# Fetch project details
data "ovh_cloud_project" "project" {
  service_name = var.inputs.ovh_provider.attributes.project_id
}

# Create the object storage container
resource "ovh_cloud_project_storage" "container" {
  service_name = var.inputs.ovh_provider.attributes.project_id
  region_name  = local.region
  name         = local.container_name

  # Versioning configuration
  versioning = var.instance.spec.versioning_enabled ? {
    status = "enabled"
  } : null

  # Encryption configuration
  encryption = var.instance.spec.encryption_enabled ? {
    sse_algorithm = var.instance.spec.encryption_algorithm
  } : null

  # Replication configuration
  replication = var.instance.spec.replication_enabled ? {
    rules = [{
      id                        = "replication-rule-1"
      status                    = "enabled"
      priority                  = 1
      delete_marker_replication = "enabled"

      destination = {
        name          = "${local.container_name}-replica"
        region        = var.instance.spec.replication_region
        storage_class = "STANDARD"
      }

      filter = {
        prefix = ""
      }
    }]
  } : null

  lifecycle {
    prevent_destroy = true
  }
}

# Create a user for accessing the container
resource "ovh_cloud_project_user" "storage_user" {
  service_name = var.inputs.ovh_provider.attributes.project_id
  description  = "User for ${local.container_name} storage access"
  role_names   = ["objectstore_operator"]
}

# Generate S3 credentials for the user
resource "ovh_cloud_project_user_s3_credential" "storage_credentials" {
  service_name = var.inputs.ovh_provider.attributes.project_id
  user_id      = ovh_cloud_project_user.storage_user.id
}

# Set S3 policy to grant access to the specific storage container
resource "ovh_cloud_project_user_s3_policy" "storage_policy" {
  service_name = ovh_cloud_project_user.storage_user.service_name
  user_id      = ovh_cloud_project_user.storage_user.id
  policy = jsonencode({
    "Statement" : [{
      "Sid" : "RWContainer",
      "Effect" : "Allow",
      "Action" : [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:ListMultipartUploadParts",
        "s3:ListBucketMultipartUploads",
        "s3:AbortMultipartUpload",
        "s3:GetBucketLocation"
      ],
      "Resource" : [
        "arn:aws:s3:::${local.container_name}",
        "arn:aws:s3:::${local.container_name}/*"
      ]
    }]
  })
}

# Generate S3 endpoint URL and credentials
locals {
  # Extract S3 endpoint from virtual_host by removing the container name prefix
  virtual_host_clean = trimprefix(ovh_cloud_project_storage.container.virtual_host, "https://")
  s3_endpoint        = "https://${replace(local.virtual_host_clean, "${local.container_name}.", "")}"

  # Container URL using virtual host from resource
  container_url = "https://${local.virtual_host_clean}"

  # Access credentials
  access_key = ovh_cloud_project_user_s3_credential.storage_credentials.access_key_id
  secret_key = ovh_cloud_project_user_s3_credential.storage_credentials.secret_access_key
}

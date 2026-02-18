locals {
  # Generate unique service account ID
  sa_id = "${var.instance_name}-${var.environment.unique_name}"

  # Service account ID must be between 6 and 30 characters
  # and can only contain lowercase alphanumeric characters and hyphens
  sa_account_id = substr(
    replace(lower(local.sa_id), "/[^a-z0-9-]/", "-"),
    0,
    30
  )

  # Default region from cloud account
  default_region = var.inputs.cloud_account.attributes.region

  # Flatten IAM bindings for easier resource iteration
  iam_bindings_flat = flatten([
    for binding in var.instance.spec.iam_bindings : [
      {
        key           = "${binding.resource_type}-${binding.resource_name}-${binding.role}"
        resource_type = binding.resource_type
        resource_name = binding.resource_name
        role          = binding.role
        location      = lookup(binding, "location", local.default_region)
      }
    ]
  ])

  # Convert to map for for_each usage
  iam_bindings_map = {
    for item in local.iam_bindings_flat :
    item.key => item
  }

  # Group IAM bindings by resource type for filtering
  iam_by_type = {
    for k, v in local.iam_bindings_map :
    v.resource_type => v...
  }
}

# Create the service account
resource "google_service_account" "this" {
  account_id   = local.sa_account_id
  display_name = var.instance.spec.display_name
  description  = var.instance.spec.description
  project      = var.inputs.cloud_account.attributes.project_id
}

# Project-level IAM bindings
resource "google_project_iam_member" "this" {
  for_each = {
    for k, v in local.iam_bindings_map :
    k => v if v.resource_type == "project"
  }

  project = var.inputs.cloud_account.attributes.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.this.email}"
}

# Storage bucket IAM bindings
resource "google_storage_bucket_iam_member" "this" {
  for_each = {
    for k, v in local.iam_bindings_map :
    k => v if v.resource_type == "storage_bucket"
  }

  bucket = each.value.resource_name
  role   = each.value.role
  member = "serviceAccount:${google_service_account.this.email}"
}

# BigQuery dataset IAM bindings
resource "google_bigquery_dataset_iam_member" "this" {
  for_each = {
    for k, v in local.iam_bindings_map :
    k => v if v.resource_type == "bigquery_dataset"
  }

  dataset_id = each.value.resource_name
  role       = each.value.role
  member     = "serviceAccount:${google_service_account.this.email}"
}

# Pub/Sub topic IAM bindings
resource "google_pubsub_topic_iam_member" "this" {
  for_each = {
    for k, v in local.iam_bindings_map :
    k => v if v.resource_type == "pubsub_topic"
  }

  topic  = each.value.resource_name
  role   = each.value.role
  member = "serviceAccount:${google_service_account.this.email}"
}

# Pub/Sub subscription IAM bindings
resource "google_pubsub_subscription_iam_member" "this" {
  for_each = {
    for k, v in local.iam_bindings_map :
    k => v if v.resource_type == "pubsub_subscription"
  }

  subscription = each.value.resource_name
  role         = each.value.role
  member       = "serviceAccount:${google_service_account.this.email}"
}

# Secret Manager secret IAM bindings
resource "google_secret_manager_secret_iam_member" "this" {
  for_each = {
    for k, v in local.iam_bindings_map :
    k => v if v.resource_type == "secret_manager_secret"
  }

  secret_id = each.value.resource_name
  role      = each.value.role
  member    = "serviceAccount:${google_service_account.this.email}"
}

# Cloud KMS crypto key IAM bindings
resource "google_kms_crypto_key_iam_member" "this" {
  for_each = {
    for k, v in local.iam_bindings_map :
    k => v if v.resource_type == "kms_crypto_key"
  }

  crypto_key_id = each.value.resource_name
  role          = each.value.role
  member        = "serviceAccount:${google_service_account.this.email}"
}

# Cloud KMS key ring IAM bindings
resource "google_kms_key_ring_iam_member" "this" {
  for_each = {
    for k, v in local.iam_bindings_map :
    k => v if v.resource_type == "kms_key_ring"
  }

  key_ring_id = each.value.resource_name
  role        = each.value.role
  member      = "serviceAccount:${google_service_account.this.email}"
}

# Artifact Registry repository IAM bindings
resource "google_artifact_registry_repository_iam_member" "this" {
  for_each = {
    for k, v in local.iam_bindings_map :
    k => v if v.resource_type == "artifact_registry_repository"
  }

  repository = each.value.resource_name
  role       = each.value.role
  member     = "serviceAccount:${google_service_account.this.email}"
}

# Cloud Run service IAM bindings
resource "google_cloud_run_service_iam_member" "this" {
  for_each = {
    for k, v in local.iam_bindings_map :
    k => v if v.resource_type == "cloud_run_service"
  }

  service  = each.value.resource_name
  location = each.value.location
  role     = each.value.role
  member   = "serviceAccount:${google_service_account.this.email}"
}

# Cloud Tasks queue IAM bindings
resource "google_cloud_tasks_queue_iam_member" "this" {
  for_each = {
    for k, v in local.iam_bindings_map :
    k => v if v.resource_type == "cloud_tasks_queue"
  }

  name     = each.value.resource_name
  location = each.value.location
  role     = each.value.role
  member   = "serviceAccount:${google_service_account.this.email}"
}

# Cloud Run v2 Job IAM bindings
resource "google_cloud_run_v2_job_iam_member" "this" {
  for_each = {
    for k, v in local.iam_bindings_map :
    k => v if v.resource_type == "cloud_run_job"
  }

  name     = each.value.resource_name
  location = each.value.location
  role     = each.value.role
  member   = "serviceAccount:${google_service_account.this.email}"
}

# Optionally create a service account key
resource "google_service_account_key" "this" {
  count = var.instance.spec.create_key ? 1 : 0

  service_account_id = google_service_account.this.name
}

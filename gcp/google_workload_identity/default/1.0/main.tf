module "unique_name" {
  count           = local.gcp_sa_name == "" || local.gcp_sa_name == null ? 1 : 0
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 30
  resource_name   = local.name
  resource_type   = "google_workload_identity"
  is_k8s          = false
  globally_unique = true
}

data "google_service_account" "cluster_service_account" {
  count = local.use_existing_gcp_sa ? 1 : 0

  account_id = local.gcp_given_name
  project    = local.project_id
}

resource "google_service_account" "cluster_service_account" {
  count = local.use_existing_gcp_sa ? 0 : 1

  account_id   = local.gcp_given_name
  display_name = substr("GCP SA bound to K8S SA ${local.project_id} ${local.k8s_given_name}", 0, 100)
  description  = local.gcp_sa_description
  project      = local.project_id
}

resource "kubernetes_service_account" "main" {
  count = local.use_existing_k8s_sa ? 0 : 1

  automount_service_account_token = local.automount_service_account_token


  metadata {
    name      = local.k8s_given_name
    namespace = local.namespace
    annotations = {
      "iam.gke.io/gcp-service-account" = local.gcp_sa_email
    }
    labels = {
      resource_type = "workload_identity"
      resource_name = var.instance_name
    }
  }
}

resource "null_resource" "annotate-sa" {
  count = local.use_existing_k8s_sa && local.annotate_k8s_sa ? 1 : 0

  triggers = {
    cluster_auth  = base64encode(jsonencode(var.inputs.gke_cluster.attributes))
    ksa_namespace = local.output_k8s_namespace
    ksa_name      = local.k8s_given_name
    gcp_sa_email  = local.gcp_sa_email
  }

  provisioner "local-exec" {
    when = create
    environment = {
      CLUSTER_ENDPOINT = sensitive(var.inputs.gke_cluster.cluster_endpoint)
      CLUSTER_CA_CERT  = sensitive(base64encode(var.inputs.gke_cluster.cluster_ca_certificate))
      EXEC_API_VERSION = sensitive(var.inputs.gke_cluster.kubernetes_provider_exec.api_version)
      EXEC_COMMAND     = sensitive(var.inputs.gke_cluster.kubernetes_provider_exec.command)
      EXEC_ARGS        = sensitive(jsonencode(var.inputs.gke_cluster.kubernetes_provider_exec.args))
    }
    command = <<EOT
    /bin/bash scripts/run_with_exec_kubeconfig.sh kubectl annotate --overwrite sa -n ${self.triggers.ksa_namespace} ${self.triggers.ksa_name} iam.gke.io/gcp-service-account=${self.triggers.gcp_sa_email}
    EOT
  }
}

resource "google_service_account_iam_member" "main" {
  service_account_id = local.use_existing_gcp_sa ? data.google_service_account.cluster_service_account[0].name : google_service_account.cluster_service_account[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.k8s_sa_gcp_derived_name
}

resource "google_project_iam_member" "workload_identity_sa_bindings" {
  for_each = toset(local.roles)

  project = local.project_id
  role    = each.value
  member  = local.gcp_sa_fqn
}


variable "instance" {
  description = "Workload Identity is the recommended way to access GCP services from Kubernetes. [Read more] (https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)."
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      # Required fields
      name                = string
      use_existing_gcp_sa = bool
      use_existing_k8s_sa = bool
      roles = map(object({
        role = string
      }))

      # Optional fields with defaults handled in locals.tf
      gcp_sa_name                     = optional(string)
      gcp_sa_description              = optional(string)
      k8s_sa_name                     = optional(string)
      namespace                       = optional(string)
      annotate_k8s_sa                 = optional(bool, false)
      automount_service_account_token = optional(bool, false)
    })
  })
}
variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
}
variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    project     = string
    namespace   = string
  })
}
variable "inputs" {
  description = "Input dependencies from other resources defined in facets.yaml inputs section"
  type = object({
    # Required: GCP Cloud Account
    cloud_account = object({
      attributes = optional(object({
        credentials = optional(string)
        project_id  = optional(string)
        region      = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })

    # Required: GKE Cluster
    gke_cluster = object({
      attributes = optional(object({
        auto_upgrade           = optional(string)
        cloud_provider         = optional(string)
        cluster_ca_certificate = optional(string)
        cluster_endpoint       = optional(string)
        cluster_id             = optional(string)
        cluster_ipv4_cidr      = optional(string)
        cluster_location       = optional(string)
        cluster_name           = optional(string)
        cluster_version        = optional(string)
        kubernetes_provider_exec = optional(object({
          api_version = optional(string)
          args        = optional(list(string))
          command     = optional(string)
        }))
        maintenance_policy_enabled             = optional(string)
        master_authorized_networks_config      = optional(list(string))
        network                                = optional(string)
        pods_range_name                        = optional(string)
        project_id                             = optional(string)
        region                                 = optional(string)
        release_channel                        = optional(string)
        secrets                                = optional(list(string))
        services_range_name                    = optional(string)
        subnetwork                             = optional(string)
        workload_identity_config_workload_pool = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}


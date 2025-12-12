variable "instance" {
  description = "Workload Identity is the recommended way to access GCP services from Kubernetes. [Read more] (https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)."
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
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
    gke_cluster = object({
      project_id             = string
      cluster_endpoint       = string
      cluster_ca_certificate = string
      kubernetes_provider_exec = object({
        api_version = string
        command     = string
        args        = list(string)
      })
    })
  })
}


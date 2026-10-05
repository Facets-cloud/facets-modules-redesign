locals {
  default_minio = {
    mode = "distributed"
    auth = {
      rootUser     = lookup(lookup(local.minio, "auth", {}), "rootUser", "admin")
      rootPassword = lookup(lookup(local.minio, "auth", {}), "rootPassword", local.minio_password)
    }
    tolerations = local.facets_tolerations
    image = {
      registry = "docker.io"
      repository = "bitnamilegacy/minio"
    }
    volumePermissions = {
      image = {
        registry = "docker.io"
        repository = "bitnamilegacy/os-shell"
        tag = "11-debian-11-r90"
      }
    }
    provisioning = {
      enabled = true
      users = [
        {
          username = local.minio_username
          password = local.minio_password
          disabled = false
          policies = [
            "readwrite",
            "consoleAdmin",
            "diagnostics"
          ],
          setPolicies = false
        }
      ]
      buckets = [
        {
          name = local.minio_bucket
        }
      ]
    }

    metrics = {
      serviceMonitor = {
        enabled = true
      }
    }

    resources = {
      requests = {
        memory = "100Mi"
        cpu    = "100m"
      }
      limits = {
        memory = "1000Mi"
        cpu    = "1000m"
      }
    }
  }
}

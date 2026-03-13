# GCP Compute Engine health check — used by the MIG auto-healing policy to detect
# and replace unhealthy VM instances. Only created when check_type != "None".
resource "google_compute_health_check" "this" {
  count   = local.health_check_enabled ? 1 : 0
  name    = local.vm_name
  project = local.project_id

  check_interval_sec  = try(var.instance.spec.runtime.health_checks.check_interval, 30)
  timeout_sec         = try(var.instance.spec.runtime.health_checks.timeout, 10)
  healthy_threshold   = try(var.instance.spec.runtime.health_checks.healthy_threshold, 1)
  unhealthy_threshold = try(var.instance.spec.runtime.health_checks.unhealthy_threshold, 3)

  dynamic "http_health_check" {
    for_each = local.health_check_type == "HttpCheck" ? [1] : []
    content {
      port         = var.instance.spec.runtime.health_checks.port
      request_path = try(var.instance.spec.runtime.health_checks.http_path, "/")
    }
  }

  dynamic "tcp_health_check" {
    for_each = local.health_check_type == "TcpCheck" ? [1] : []
    content {
      port = var.instance.spec.runtime.health_checks.port
    }
  }
}

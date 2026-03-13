# Autoscaler watches the MIG and adjusts instance count to maintain cpu_target utilization.
# GCP does not allow an autoscaler on a stateful MIG — skipped when stateful=true.
resource "google_compute_autoscaler" "this" {
  count   = lookup(var.instance.spec, "stateful", false) ? 0 : 1
  name    = local.vm_name
  project = local.project_id
  zone    = local.zone
  target  = google_compute_instance_group_manager.this.id

  autoscaling_policy {
    min_replicas    = lookup(var.instance.spec.runtime.autoscaling, "min", 1)
    max_replicas    = lookup(var.instance.spec.runtime.autoscaling, "max", 3)
    cooldown_period = lookup(var.instance.spec.runtime.autoscaling, "cooldown_period", 60)

    # Scale based on average CPU utilization across all instances in the MIG
    cpu_utilization {
      target = lookup(var.instance.spec.runtime.autoscaling, "cpu_target", 0.6)
    }
  }
}

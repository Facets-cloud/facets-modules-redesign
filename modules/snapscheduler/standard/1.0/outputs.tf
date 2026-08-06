locals {
  output_attributes = {
    namespace     = helm_release.snapschedule.namespace
    release_name  = helm_release.snapschedule.name
    chart         = helm_release.snapschedule.chart
    version       = helm_release.snapschedule.version
    status        = helm_release.snapschedule.status
    operator_name = "snapscheduler"
  }

  output_interfaces = {}
}

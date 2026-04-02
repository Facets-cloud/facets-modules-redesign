locals {
  output_attributes = {
    release_name = helm_release.snapschedule.name
    namespace    = helm_release.snapschedule.namespace
    chart        = helm_release.snapschedule.chart
    version      = helm_release.snapschedule.version
    status       = helm_release.snapschedule.status
  }

  output_interfaces = {}
}

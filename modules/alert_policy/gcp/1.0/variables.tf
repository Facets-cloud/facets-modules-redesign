variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      policies = map(object({
        display_name  = string
        enabled       = optional(bool, true)
        severity      = optional(string, "WARNING")
        documentation = optional(string)
        condition = object({
          type         = optional(string, "metric_threshold")
          display_name = optional(string)
          metric_type  = string
          filter       = optional(string)
          comparison   = optional(string, "COMPARISON_GT")
          threshold    = optional(number, 0)
          duration     = optional(string, "60s")
          aggregation = optional(object({
            alignment_period     = optional(string, "60s")
            per_series_aligner   = optional(string, "ALIGN_SUM")
            cross_series_reducer = optional(string, "REDUCE_SUM")
            group_by_fields      = optional(list(string), [])
          }), {})
        })
        combiner   = optional(string, "OR")
        auto_close = optional(string, "86400s")
        labels     = optional(map(string), {})
      }))
    })
  })
}

variable "instance_name" {
  type        = string
  description = "Unique name for this alert policy resource"
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  type = object({
    gcp_provider = object({
      attributes = object({
        project_id = string
        region     = string
      })
    })
    notification_channels = object({
      channel_ids   = map(string)
      channel_names = map(string)
      project_id    = string
    })
  })
}

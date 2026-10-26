variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      replicator_arn             = string
      topic_name_pattern         = string
      consumer_group_pattern     = string
      starting_position          = string
      detect_and_copy_new_topics = bool
    })
  })
}

variable "instance_name" { type = string }

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = optional(object({
        aws_iam_role = optional(string)
        aws_region   = optional(string)
        external_id  = optional(string)
        session_name = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    source_kafka = object({
      attributes = optional(object({
        cluster_name  = optional(string)
        kafka_version = optional(string)
        namespace     = optional(string)
      }), {})
      interfaces = optional(object({
        cluster = optional(object({
          connection_string = optional(string)
          endpoint          = optional(string)
          endpoints         = optional(map(string), {})
          password          = optional(string)
          secrets           = optional(list(string), [])
          username          = optional(string)
        }))
      }), {})
    })
    destination_kafka = object({
      attributes = optional(object({
        cluster_name  = optional(string)
        kafka_version = optional(string)
        namespace     = optional(string)
      }), {})
      interfaces = optional(object({
        cluster = optional(object({
          connection_string = optional(string)
          endpoint          = optional(string)
          endpoints         = optional(map(string), {})
          password          = optional(string)
          secrets           = optional(list(string), [])
          username          = optional(string)
        }))
      }), {})
    })
  })
}

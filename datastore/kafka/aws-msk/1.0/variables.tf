variable "instance" {
  description = "AWS Managed Streaming for Apache Kafka cluster with secure defaults and automatic scaling"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        kafka_version = string
        instance_type = string
      })
      sizing = object({
        number_of_broker_nodes = number
        volume_size            = number
        client_subnets_count   = number
      })
      imports = optional(object({
        import_existing   = optional(bool, false)
        cluster_arn       = optional(string)
        security_group_id = optional(string)
      }), {})
    })
  })

  validation {
    condition = (
      contains(["3.4.0", "3.5.1", "3.6.0", "3.7.x", "3.7.x.kraft", "3.8.x", "3.8.x.kraft", "3.9.x", "3.9.x.kraft", "4.0.x.kraft"], var.instance.spec.version_config.kafka_version) ||
      contains(["2.8.1"], var.instance.spec.version_config.kafka_version)
    )
    error_message = "Kafka version must be one of the supported versions. Recommended versions: 3.4.0, 3.5.1, 3.6.0, 3.7.x, 3.7.x.kraft, 3.8.x, 3.8.x.kraft, 3.9.x, 3.9.x.kraft, 4.0.x.kraft. Note: Legacy version 2.8.1 may not be available in all AWS regions."
  }

  validation {
    condition     = contains(["kafka.t3.small", "kafka.m5.large", "kafka.m5.xlarge", "kafka.m5.2xlarge", "kafka.m5.4xlarge", "kafka.m7g.large", "kafka.m7g.xlarge", "kafka.m7g.2xlarge", "kafka.m7g.4xlarge"], var.instance.spec.version_config.instance_type)
    error_message = "Instance type must be one of: kafka.t3.small, kafka.m5.large, kafka.m5.xlarge, kafka.m5.2xlarge, kafka.m5.4xlarge, kafka.m7g.large, kafka.m7g.xlarge, kafka.m7g.2xlarge, kafka.m7g.4xlarge"
  }

  validation {
    condition     = var.instance.spec.sizing.number_of_broker_nodes >= 1 && var.instance.spec.sizing.number_of_broker_nodes <= 15
    error_message = "Number of broker nodes must be between 1 and 15"
  }

  validation {
    condition     = var.instance.spec.sizing.volume_size >= 1 && var.instance.spec.sizing.volume_size <= 16384
    error_message = "Volume size must be between 1 and 16384 GB"
  }

  validation {
    condition     = var.instance.spec.sizing.client_subnets_count >= 2 && var.instance.spec.sizing.client_subnets_count <= 3
    error_message = "Client subnets count must be between 2 and 3"
  }
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
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    aws_cloud_account = object({
      attributes = object({
        aws_iam_role = string
        session_name = string
        external_id  = string
        aws_region   = string
      })
    })
    vpc_details = object({
      attributes = object({
        vpc_id             = string
        private_subnet_ids = list(string)
        vpc_cidr_block     = string
        availability_zones = list(string)
      })
    })
  })
}
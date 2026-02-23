variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec    = any
  })

}


variable "instance_name" {
  type        = string
  description = "Unique architectural name from blueprint"


}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    namespace   = string
    region      = string
    cloud_tags  = optional(map(string), {})
  })
}


variable "inputs" {
  description = "Input dependency from other modules"
  type = object({
    cloud_account = object({
      attributes = object({
        aws_iam_role = string
        session_name = string
        external_id  = string
        aws_region   = string
      })
    })
  })

}


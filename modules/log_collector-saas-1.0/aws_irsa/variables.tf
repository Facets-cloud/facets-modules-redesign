variable "iam_arns" {
  type = any
}

variable "iam_role_name" {
  type = string 
}

variable "namespace" {
  type = string 
}

variable "sa_name" {
  type = string 
}

variable "eks_oidc_provider_arn" {
  type = string
}

variable "max_session_duration" {
  description = "Maximum CLI/API session duration in seconds between 3600 and 43200"
  type        = number
  default     = null
}

variable "tags" {
  description = "A map of tags to add to the IAM role (used for cost attribution)"
  type        = map(any)
  default     = {}
}

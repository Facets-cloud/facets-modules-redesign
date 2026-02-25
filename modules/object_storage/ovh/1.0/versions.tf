terraform {
  required_version = ">= 1.5.7"

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 2.7.0"
    }
  }
}

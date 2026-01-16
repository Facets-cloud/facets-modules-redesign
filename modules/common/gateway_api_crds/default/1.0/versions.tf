terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    http = {
      source  = "hashicorp/http"
      version = ">= 3.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
  }
}

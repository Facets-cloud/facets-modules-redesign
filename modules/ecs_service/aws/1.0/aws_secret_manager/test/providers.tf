provider "helm" {
  kubernetes {
    config_path = "~/Downloads/aws-infra-dev-kubeconfig"
  }
}

provider "kubernetes" {
  config_path = "~/Downloads/aws-infra-dev-kubeconfig"
}


provider "aws" {
  region = "ap-south-1"
}

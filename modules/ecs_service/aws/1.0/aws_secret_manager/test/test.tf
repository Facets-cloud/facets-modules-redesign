locals {
  definition_object = jsondecode(file("test.json"))
}

module "test-aws-secret-manager" {
  source = "../"

  instance      = local.definition_object
  instance_name = "test-aws-secret-manager"
  environment = {
    namespace   = "default"
    unique_name = "k8s"
    cloud_tags = {
      facetscontrolplane = "facetsdemo"
      cluster            = "aws-infra-dev"
      facetsclustername  = "infra-dev-aws-infra-dev"
    }
    baseinfra = {
      vpc_details = {
        vpc_id   = "vpc-02e8ad9b5be25deef"
        vpc_cidr = "10.30.0.0/16"
        private_subnet_objects = {
          cidr = ["10.30.0.0/16"]
          id   = ["subnet-05947873b172759c8", "subnet-0ce3995471477f0a6"]
        }
      }
    }
  }
}

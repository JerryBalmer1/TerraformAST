terraform {
  required_providers {
    null = {
      source = "hashicorp/null"
    }
  }
}

resource "null_resource" "subnet" {
  count = var.instance_count

  triggers = {
    zone = var.availability_zone
  }
}

module "endpoint" {
  source = "./modules/endpoint"
  host   = "localhost"
  port   = 8080
}

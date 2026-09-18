terraform {
  required_version = ">= 1.5.0"

  required_providers {
    null  = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "null" {}
provider "local" {}

locals {
  name_prefix = "demo"
  enabled     = var.enable_public_ip
}

resource "null_resource" "marker" {
  triggers = {
    region = var.aws_region
  }
}

resource "terraform_data" "placeholder" {
  input = var.instance_count
}

data "local_file" "readme" {
  filename = "${path.module}/../README.md"
}

module "network" {
  source         = "./modules/network"
  aws_region     = var.aws_region
  instance_count = var.instance_count
  tags           = var.tags
}

check "region_set" {
  assert {
    condition     = length(var.aws_region) > 0
    error_message = "aws_region must not be empty."
  }
}

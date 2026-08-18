
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }
  }
}

provider "local" {
  # Configuration options
}

# A basic string variable with a fallback default value
variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources into"
  default     = "us-east-1"
}

# A number variable
variable "instance_count" {
  type        = number
  description = "Number of EC2 instances to create"
  default     = 2
}

# A boolean variable used for conditional logic
variable "enable_public_ip" {
  type        = bool
  description = "If true, assign a public IP to the instance"
  default     = false
}


# A map variable (key-value pairs)
variable "tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default = {
    Environment = "Dev"
    ManagedBy   = "Terraform"
  }
}

module "main" {
  source     = "./tests/terraform"
}

output "main" {
  value = module.main
}

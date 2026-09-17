variable "aws_region" {
  type        = string
  description = "Region name used as a plain string fixture"
  default     = "us-east-1"
}

variable "instance_count" {
  type        = number
  description = "How many instances a caller would request"
  default     = 2
}

variable "enable_public_ip" {
  type        = bool
  description = "Toggle used for conditional fixtures"
  default     = false
}

variable "availability_zones" {
  type        = list(string)
  description = "List fixture"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "tags" {
  type        = map(string)
  description = "Map fixture"
  default = {
    Environment = "Dev"
    ManagedBy   = "Terraform"
  }
}

variable "endpoint" {
  type = object({
    host = string
    port = number
  })
  description = "Object fixture"
  default = {
    host = "localhost"
    port = 8080
  }
}

variable "pair" {
  type        = tuple([string, number])
  description = "Tuple fixture"
  default     = ["blue", 1]
}

variable "aws_region" {
  type = string
}

variable "instance_count" {
  type = number
}

variable "availability_zone" {
  type    = string
  default = "us-east-1a"
}

variable "tags" {
  type = map(string)
}

output "region" {
  value       = var.aws_region
  description = "Echo the string variable"
}

output "network" {
  value       = module.network
  description = "Nested module outputs"
}

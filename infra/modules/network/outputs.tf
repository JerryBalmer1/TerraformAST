output "subnet_ids" {
  value = null_resource.subnet[*].id
}

output "endpoint" {
  value = module.endpoint.address
}

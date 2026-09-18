resource "terraform_data" "listener" {
  input = {
    host = var.host
    port = var.port
  }
}

output "address" {
  value = "${var.host}:${var.port}"
}

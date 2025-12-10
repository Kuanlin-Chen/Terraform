terraform {
  required_version = ">= 1.0"
}

variable "password" {
  description = "Demo secret"
  type        = string
  sensitive   = true
}

resource "local_file" "demo" {
  filename = "${path.module}/output.txt"
  content  = "Password is ${var.password}"
}

output "password_output" {
  value     = var.password
  sensitive = true
}

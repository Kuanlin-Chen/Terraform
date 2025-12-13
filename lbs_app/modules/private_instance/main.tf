resource "aws_instance" "web_server" {
    ami                         = var.ami_id
    instance_type               = var.instance_type
    security_groups             = var.security_groups
    associate_public_ip_address = false
    user_data                   = var.user_data
}
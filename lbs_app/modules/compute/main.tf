resource "aws_instance" "web_server" {
    ami                         = var.ami_id
    instance_type               = var.instance_type
    security_groups             = var.security_group_ids
    associate_public_ip_address = var.associate_public_ip
    user_data                   = var.user_data
}
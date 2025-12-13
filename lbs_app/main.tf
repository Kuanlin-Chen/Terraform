terraform {
  backend "s3" {
    bucket       = "lbsapp-tf-state"
    key          = "terraform.tfstate"
    region       = "ap-northeast-3"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws",
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-3" # Osaka
}

data "aws_vpc" "default_vpc" {
  default = true
}

data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

# Security Group for Instances
resource "aws_security_group" "instance_sg" {
  name = "instance_sg"
}
resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.default_vpc.cidr_block]
  security_group_id = aws_security_group.instance_sg.id
}

module "instance_1" {
  source = "./modules/private_instance"

  ami_id                     = "ami-09a38e2e7a3cc42de" # Ubuntu Server 24.04 LTS
  instance_type              = var.instance_type
  security_groups            = [aws_security_group.instance_sg.name]
  user_data                  = <<-EOF
                #!/bin/bash
                echo "Hello, World 111" > index.html
                sudo python3 -m http.server 8080 &
                EOF
}

module "instance_2" {
  source = "./modules/private_instance"

  ami_id                     = "ami-09a38e2e7a3cc42de" # Ubuntu Server 24.04 LTS
  instance_type              = var.instance_type
  security_groups            = [aws_security_group.instance_sg.name]
  user_data                  = <<-EOF
                #!/bin/bash
                echo "Hello, World 222" > index.html
                sudo python3 -m http.server 8080 &
                EOF
}

resource "aws_kms_key" "s3_kms_key" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "bucket" {
  bucket_prefix = "lbsapp-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_kms_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name = "alb_sg"
}
resource "aws_security_group_rule" "allow_alb_http_inbound" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Allow from anywhere
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "allow_alb_all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_lb" "load_balancer" {
  name               = "web-app-lb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default_subnets.ids
  security_groups    = [aws_security_group.alb_sg.id]

  lifecycle {
    postcondition {
      condition = self.dns_name != null && self.dns_name != ""
      error_message = "Load balancer should have a DNS name assigned."
    }
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_target_group" "target_group" {
  name     = "web-app-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "attach_instance_1" {
  target_group_arn = aws_lb_target_group.target_group.arn
  target_id        = module.instance_1.instance_id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "attach_instance_2" {
  target_group_arn = aws_lb_target_group.target_group.arn
  target_id        = module.instance_2.instance_id
  port             = 8080
}

resource "aws_lb_listener_rule" "forward_to_tg" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
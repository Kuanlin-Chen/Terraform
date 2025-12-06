terraform {
	required_version = ">= 1.0.0"
	required_providers {
		aws = {
			source  = "hashicorp/aws"
			version = "~> 5.0"
		}
	}
}

provider "aws" {
	region = var.region
}

resource "aws_s3_bucket" "vpce_bucket" {
	bucket        = "vpc-endpoint-latest-20251129"
	force_destroy = true
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "vpce_bucket_policy" {
    statement {
        sid    = "AllowAdministratorFullAccess"
        effect = "Allow"

        principals {
            type        = "AWS"
            identifiers = [
                "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/Administrator"
            ]
        }

        actions = ["s3:*"]
        resources = [
            aws_s3_bucket.vpce_bucket.arn,
            "${aws_s3_bucket.vpce_bucket.arn}/*"
        ]
    }
}

resource "aws_s3_bucket_policy" "vpce_policy" {
	bucket = aws_s3_bucket.vpce_bucket.id
	policy = data.aws_iam_policy_document.vpce_bucket_policy.json
}

# VPC Endpoint
resource "aws_vpc_endpoint" "s3" {
	vpc_id            = aws_vpc.this.id
	service_name      = "com.amazonaws.${var.region}.s3"
	vpc_endpoint_type = "Gateway"
	route_table_ids   = [aws_route_table.private_rt.id]
}

resource "aws_instance" "web" {
	ami                         = var.ami_id
	instance_type               = var.instance_type
	subnet_id                   = aws_subnet.private.id
	key_name                    = var.key_name
	associate_public_ip_address = false
	vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
	iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
}

# Networking
data "aws_availability_zones" "az" { }

resource "aws_vpc" "this" {
	cidr_block           = "10.0.0.0/16"
	enable_dns_support   = true
	enable_dns_hostnames = true
}

resource "aws_internet_gateway" "igw" {
	vpc_id = aws_vpc.this.id
}

resource "aws_subnet" "private" {
	vpc_id                  = aws_vpc.this.id
	cidr_block              = "10.0.2.0/24"
	map_public_ip_on_launch = false
	availability_zone       = data.aws_availability_zones.az.names[0]
}

resource "aws_route_table" "private_rt" {
	vpc_id = aws_vpc.this.id
}

resource "aws_route_table_association" "private_assoc" {
	subnet_id      = aws_subnet.private.id
	route_table_id = aws_route_table.private_rt.id
}

# Security Group
resource "aws_security_group" "ec2_sg" {
	name        = "ec2-sg"
	vpc_id      = aws_vpc.this.id
	description = "SSH access"
	
	ingress {
		description = "SSH"
		from_port   = 22
		to_port     = 22
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	# Allow SSM/VPC Endpoint HTTPS
	ingress {
		description = "SSM/VPC Endpoint HTTPS"
		from_port   = 443
		to_port     = 443
		protocol    = "tcp"
		cidr_blocks = [aws_vpc.this.cidr_block]
	}
	
	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
	name               = "ec2-s3-upload-role"
	assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

data "aws_iam_policy_document" "ec2_assume_role" {
	statement {
		actions = ["sts:AssumeRole"]
		principals {
			type        = "Service"
			identifiers = ["ec2.amazonaws.com"]
		}
	}
}

resource "aws_iam_role_policy_attachment" "ec2_s3_attach" {
	role       = aws_iam_role.ec2_role.name
	policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
	role       = aws_iam_role.ec2_role.name
	policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
	name = "ec2-s3-profile"
	role = aws_iam_role.ec2_role.name
}

# 3 Required SSM VPC Endpoints
resource "aws_vpc_endpoint" "ssm" {
	vpc_id              = aws_vpc.this.id
	service_name        = "com.amazonaws.${var.region}.ssm"
	vpc_endpoint_type   = "Interface"
	subnet_ids          = [aws_subnet.private.id]
	security_group_ids  = [aws_security_group.ec2_sg.id]
	private_dns_enabled = true
}

# SSM Messages
resource "aws_vpc_endpoint" "ssmmessages" {
	vpc_id              = aws_vpc.this.id
	service_name        = "com.amazonaws.${var.region}.ssmmessages"
	vpc_endpoint_type   = "Interface"
	subnet_ids          = [aws_subnet.private.id]
	security_group_ids  = [aws_security_group.ec2_sg.id]
	private_dns_enabled = true
}

# EC2 Messages
resource "aws_vpc_endpoint" "ec2messages" {
	vpc_id              = aws_vpc.this.id
	service_name        = "com.amazonaws.${var.region}.ec2messages"
	vpc_endpoint_type   = "Interface"
	subnet_ids          = [aws_subnet.private.id]
	security_group_ids  = [aws_security_group.ec2_sg.id]
	private_dns_enabled = true
}
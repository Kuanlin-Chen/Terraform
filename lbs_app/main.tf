terraform {
    backend "s3" {
        bucket         = "lbsapp-tf-state"
        key            = "terraform.tfstate"
        region         = "ap-east-2"
        encrypt        = true
        dynamodb_table = "lbsapp-tf-locks"
    }

    required_providers {
        aws = {
            source = "hashicorp/aws",
            version = "~> 5.0"
        }
    }
}

provider "aws" {
    region = "ap-east-2"
}

resource "aws_security_group" "instance_sg" {
    name = "instance_sg"
}

resource "aws_instance" "instance_1" {
    ami = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI
    instance_type = "t2.micro"
    security_groups = [aws_security_group.instance_sg.name]
    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World 111" > /var/www/html/index.html
                EOF
}

resource "aws_instance" "instance_2" {
    ami = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI
    instance_type = "t2.micro"
    security_groups = [aws_security_group.instance_sg.name]
    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World 222" > /var/www/html/index.html
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
          sse_algorithm = "aws:kms"
        }
    }
}
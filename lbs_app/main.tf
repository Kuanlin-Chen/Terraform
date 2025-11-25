terraform {
    backend "s3" {
        bucket         = "lbsapp-tf-state",
        key            = "terraform.tfstate",
        region         = "ap-east-2",
        encrypt        = true,
        dynamodb_table = "lbsapp-tf-locks"
    }

    required_providers {
        aws = {
            source = "hashicorp/aws",
            version = "~> 5.0"
        }
    }
}
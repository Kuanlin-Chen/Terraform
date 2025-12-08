variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-3" # Osaka
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing EC2 key pair name in ap-northeast-3"
  type        = string
  default     = "ubuntu"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-0a1c53f150dd059a2" # Amazon Linux 2023 kernel-6.12
}

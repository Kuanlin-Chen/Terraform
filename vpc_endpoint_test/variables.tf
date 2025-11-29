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

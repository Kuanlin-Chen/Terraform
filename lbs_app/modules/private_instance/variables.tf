variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-09a38e2e7a3cc42de" # Ubuntu Server 24.04 LTS
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "security_groups" {
  description = "List of security group IDs"
  type        = list(string)
  default     = []
}

variable "user_data" {
  description = "User data script for the EC2 instance"
  type        = string
  default     = ""
}
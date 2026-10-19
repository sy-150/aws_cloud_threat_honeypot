# Setting the AWS Region
variable "aws_region" {
  description = "Region AWS target"
  type        = string
  default     = "us-east-1"
}

# VPC CIDR Block
variable "vpc_cidr" {
  description = "VPC default CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

# Domain & DNS
variable "domain_name"{
  description = "Website domain name"
  type        = string
}

# Assuming IAM Role
variable "assume_role_arn"{
  description = "IAM role assuming ARN"
  type        = string
}

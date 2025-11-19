variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "ca-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "frontend_instance_type" {
  description = "EC2 instance type for the frontend server"
  type        = string
  default     = "t2.micro"
}

variable "backend_instance_type" {
  description = "EC2 instance type for the backend server"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID to launch EC2 instances"
  type        = string
  default     = "ami-0c02fb55956c7d316" # Amazon Linux 2023 AMI
}

variable "s3_bucket_name" {
  description = "S3 bucket name for DR logs"
  type        = string
  default     = "group6-dr-demo-bucket"
}

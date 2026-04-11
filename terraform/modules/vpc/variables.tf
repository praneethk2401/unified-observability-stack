variable "environment" {
    description = "Environment Name"
    type = string
}

variable "project_name" {
  description = "Project Name"
  type = string
  default = "unified-observability"
}

variable "vpc_cidr" {
    description = "CIDR block for the VPC"
    type = string
}

variable "public_subnet_cidr" {
    description = "CIDR block for the public subnet"
    type = string
}

variable "aws_region" {
  description = "AWS region"
  type = string
  default = "ap-south-2"
}

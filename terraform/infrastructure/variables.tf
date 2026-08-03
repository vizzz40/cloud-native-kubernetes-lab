variable "vpc_cidr" {
  description = "IPv4 CIDR allocated to the lab VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR allocated to the lab public subnet"
  type        = string
  default     = "10.20.1.0/24"
}

variable "aws_region" {
  description = "AWS region containing the Terraform remote backend bucket"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Name used to identify project resources"
  type        = string
  default     = "k8s-lab"
}
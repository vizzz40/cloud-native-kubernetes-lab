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

variable "admin_cidr" {
  description = "Public IPv4 address allowed to administer the cluster"
  type        = string


  //valdiation will literally validate if the value given by the user is correct or no
  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && endswith(var.admin_cidr, "/32")
    error_message = "admin_cidr must be a valid single-host IPv4 CIDR ending in /32."
  }
}

variable "instance_type" {
  description = "EC2 instance type used by Kubernetes nodes"
  type        = string
  default     = "t3.medium"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 30

  validation {
    condition     = var.root_volume_size >= 20
    error_message = "Kubernetes nodes should have at least 20 GiB of root storage."
  }
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key registered with AWS"
  type        = string
  default     = "~/.ssh/k8s-lab.pub"
}
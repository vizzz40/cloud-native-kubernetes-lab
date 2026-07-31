variable "aws_region" {
  description = "AWS region containing the Terraform backend bucket"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Name used to identify project resources"
  type        = string
  default     = "k8s-lab"
}
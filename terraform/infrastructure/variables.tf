variable "aws_region" {
  description = "AWS region where the Kubernetes lab runs"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Name used to identify lab resources"
  type        = string
  default     = "k8s-lab"
}
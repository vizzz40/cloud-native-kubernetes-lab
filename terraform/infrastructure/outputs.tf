output "vpc_id" {
  description = "ID of the Kubernetes lab VPC"
  value       = aws_vpc.lab.id
}

output "public_subnet_id" {
  description = "ID of the public subnet containing lab nodes"
  value       = aws_subnet.public.id
}

output "availability_zone" {
  description = "Availability Zone selected for the lab"
  value       = aws_subnet.public.availability_zone
}

//cluster security group below

output "cluster_security_group_id" {
  description = "Security group shared by Kubernetes nodes"
  value       = aws_security_group.cluster.id
}
output "node_public_ips" {
  description = "Public IP addresses used for SSH access"
  value = {
    for name, node in aws_instance.kubernetes_node :
    name => node.public_ip
  }
}

output "node_private_ips" {
  description = "Stable private IP addresses used inside the cluster"
  value = {
    for name, node in aws_instance.kubernetes_node :
    name => node.private_ip
  }
}

output "ubuntu_ami_id" {
  description = "Ubuntu AMI selected for the Kubernetes nodes"
  value       = data.aws_ami.ubuntu.id
}
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
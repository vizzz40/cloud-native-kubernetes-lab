resource "aws_security_group" "cluster" {
  name_prefix = "${var.project_name}-cluster-"
  description = "Network access for Kubernetes cluster nodes"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "${var.project_name}-cluster"
  }

  lifecycle {
    create_before_destroy = true
  }
}



resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.cluster.id
  description       = "SSH administration from trusted public IP"

  cidr_ipv4   = var.admin_cidr //admin traffic only
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "kubernetes_api" {
  security_group_id = aws_security_group.cluster.id
  description       = "Kubectl access to Kubernetes API"

  cidr_ipv4   = var.admin_cidr
  from_port   = 6443
  to_port     = 6443
  ip_protocol = "tcp"
}

//machines that are in the same security group will freely communicate with each other for ease rn

resource "aws_vpc_security_group_ingress_rule" "cluster_internal" {
  security_group_id = aws_security_group.cluster.id
  description       = "All private traffic between cluster nodes"

  referenced_security_group_id = aws_security_group.cluster.id
  ip_protocol                  = "-1" //all protocols all ports -- for the cluster internal comms
}

//skipping NAT gateway for now

resource "aws_vpc_security_group_egress_rule" "internet" {
  security_group_id = aws_security_group.cluster.id
  description       = "Outbound access for packages and container images"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
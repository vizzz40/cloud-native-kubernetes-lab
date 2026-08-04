data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS account

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_key_pair" "k8s_lab" {
  key_name   = "${var.project_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

locals {
  kubernetes_nodes = {
    control-plane = {
      role = "control-plane"
    }

    worker-1 = {
      role = "worker"
    }

    worker-2 = {
      role = "worker"
    }
  }
}

resource "aws_instance" "kubernetes_node" {
  for_each = local.kubernetes_nodes

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.k8s_nodes.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.k8s_lab.key_name

  instance_initiated_shutdown_behavior = "stop"

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  credit_specification {
    cpu_credits = "standard"
  }

  tags = {
    Name           = "${var.project_name}-${each.key}"
    KubernetesRole = each.value.role
  }

  volume_tags = {
    Name = "${var.project_name}-${each.key}-root"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}
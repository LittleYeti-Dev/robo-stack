resource "aws_security_group" "workstation" {
  name_prefix = "robo-stack-workstation-"
  description = "Security group for Robo Stack development workstation"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "robo-stack-workstation-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# SSH access from specified CIDR only
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.workstation.id

  description = "SSH access from allowed CIDR"
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
  cidr_ipv4   = var.allowed_ssh_cidr

  tags = {
    Name = "allow-ssh"
  }
}

# HTTP access (needed for K3s dashboard, Helm, etc.)
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.workstation.id

  description = "HTTP access"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "allow-http"
  }
}

# HTTPS access
resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.workstation.id

  description = "HTTPS access"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "allow-https"
  }
}

# K8s API server access
resource "aws_vpc_security_group_ingress_rule" "k8s_api" {
  security_group_id = aws_security_group.workstation.id

  description = "K8s API server"
  from_port   = 6443
  to_port     = 6443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "allow-k8s-api"
  }
}

# kubectl proxy access for web UI
resource "aws_vpc_security_group_ingress_rule" "kubectl_proxy" {
  security_group_id = aws_security_group.workstation.id

  description = "kubectl proxy for web UI"
  from_port   = 8001
  to_port     = 8001
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "allow-kubectl-proxy"
  }
}

# Allow internal VPC communication
resource "aws_vpc_security_group_ingress_rule" "internal" {
  security_group_id = aws_security_group.workstation.id

  description = "Internal VPC communication"
  from_port   = 0
  to_port     = 65535
  ip_protocol = "tcp"
  cidr_ipv4   = var.vpc_cidr

  tags = {
    Name = "allow-internal"
  }
}

# Internal ICMP (ping) for diagnostics
resource "aws_vpc_security_group_ingress_rule" "internal_icmp" {
  security_group_id = aws_security_group.workstation.id

  description = "Internal ICMP"
  from_port   = -1
  to_port     = -1
  ip_protocol = "icmp"
  cidr_ipv4   = var.vpc_cidr

  tags = {
    Name = "allow-internal-icmp"
  }
}

# Egress: Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.workstation.id

  description = "Allow all outbound traffic"
  from_port   = 0
  to_port     = 0
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "allow-all-egress"
  }
}

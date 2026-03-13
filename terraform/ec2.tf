# Data source: Latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# EC2 Instance: Development Workstation
resource "aws_instance" "workstation" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.workstation.id]
  associate_public_ip_address = var.associate_public_ip
  iam_instance_profile        = aws_iam_instance_profile.workstation.name

  # User data script for provisioning
  user_data = base64encode(file("${path.module}/user-data.sh"))

  # Storage configuration
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "robo-stack-root-volume"
    }
  }

  # Monitoring
  monitoring = var.enable_monitoring

  # Metadata service v2 (IMDSv2) for security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # CPU options - allow burstable
  cpu_options {
    core_count       = 2
    threads_per_core = 1
  }

  # Tags
  tags = {
    Name = var.instance_name
  }

  # Depends on IAM role to be created first
  depends_on = [
    aws_iam_instance_profile.workstation,
    aws_security_group.workstation
  ]

  # lifecycle policy to prevent accidental termination
  lifecycle {
    ignore_changes = [ami]
  }
}

# Elastic IP (optional, but useful for stable connection)
resource "aws_eip" "workstation" {
  instance = aws_instance.workstation.id
  domain   = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "robo-stack-eip"
  }
}

# CloudWatch Log Group for cloud-init logs
resource "aws_cloudwatch_log_group" "workstation" {
  name_prefix            = "/robo-stack/workstation/"
  retention_in_days      = 7

  tags = {
    Name = "robo-stack-workstation-logs"
  }
}

variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the development workstation"
  type        = string
  default     = "t3.xlarge"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access (e.g., your IP/32 or 203.0.113.0/24)"
  type        = string
  sensitive   = true
  # No default - user must specify
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "robo-stack-dev-workstation"
}

variable "enable_monitoring" {
  description = "Enable CloudWatch detailed monitoring"
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Size of root EBS volume in GB"
  type        = number
  default     = 100

  validation {
    condition     = var.root_volume_size >= 50 && var.root_volume_size <= 16384
    error_message = "Root volume size must be between 50 and 16384 GB."
  }
}

variable "root_volume_type" {
  description = "EBS volume type for root volume"
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.root_volume_type)
    error_message = "Root volume type must be gp2, gp3, io1, or io2."
  }
}

variable "associate_public_ip" {
  description = "Associate public IP to the EC2 instance"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

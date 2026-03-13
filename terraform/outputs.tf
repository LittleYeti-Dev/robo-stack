output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.workstation.id
}

output "instance_public_ip" {
  description = "Public IP address of the development workstation"
  value       = aws_instance.workstation.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the development workstation"
  value       = aws_instance.workstation.private_ip
}

output "ssh_command" {
  description = "SSH command to connect to the workstation"
  value       = "ssh -i ~/.ssh/robo-stack-dev.pem ubuntu@${aws_instance.workstation.public_ip}"
}

output "k8s_api_endpoint" {
  description = "K8s API endpoint (requires port 6443)"
  value       = "https://${aws_instance.workstation.public_ip}:6443"
}

output "kubectl_proxy_url" {
  description = "kubectl proxy URL for web-based access"
  value       = "http://${aws_instance.workstation.public_ip}:8001"
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private.id
}

output "security_group_id" {
  description = "ID of the workstation security group"
  value       = aws_security_group.workstation.id
}

output "iam_role_name" {
  description = "Name of the IAM role attached to the instance"
  value       = aws_iam_role.workstation.name
}

output "instance_profile_arn" {
  description = "ARN of the instance profile"
  value       = aws_iam_instance_profile.workstation.arn
}

output "next_steps" {
  description = "Next steps after infrastructure is deployed"
  sensitive   = true
  value = format(
    <<-EOT
    Infrastructure deployed successfully!

    Quick start:
    1. Ensure SSH key exists: ls ~/.ssh/robo-stack-dev.pem
    2. Connect to your workstation:
       %s
    3. Wait ~3-5 minutes for user-data script to complete
    4. Check installation status: systemctl status k3s
    5. Get K3s kubeconfig: cat /etc/rancher/k3s/k3s.yaml

    For kubectl proxy (web UI access):
    - ssh -i ~/.ssh/robo-stack-dev.pem -L 8001:localhost:8001 ubuntu@${aws_instance.workstation.public_ip}
    - Then visit http://localhost:8001 in your browser

    Troubleshooting:
    - SSH connection issues: Check security group allows port 22 from %s
    - K3s not running: ssh into instance and check: sudo systemctl status k3s
    - Installation logs: cat /var/log/cloud-init-output.log

    Teardown when done:
    - terraform destroy -var="allowed_ssh_cidr=YOUR_IP/32"
    EOT
    ,
    "ssh -i ~/.ssh/robo-stack-dev.pem ubuntu@${aws_instance.workstation.public_ip}",
    var.allowed_ssh_cidr
  )
}

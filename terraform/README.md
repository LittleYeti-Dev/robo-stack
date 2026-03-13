# Robo Stack AWS Development Workstation

This Terraform configuration provisions a complete development workstation on AWS EC2, mirroring the local development environment from Epic 1. It includes:

- **VPC & Networking**: VPC with public/private subnets, Internet Gateway, security groups
- **EC2 Instance**: t3.xlarge (4 vCPU, 16GB RAM) Ubuntu 22.04 LTS
- **Kubernetes**: K3s pre-installed and configured
- **Container Runtime**: Docker with full configuration
- **Development Tools**: Kubectl, Helm, Terraform, AWS CLI, GitHub CLI, Node.js, Python, Git
- **Security**: IAM roles with least-privilege permissions, IMDSv2, encrypted EBS volumes
- **Monitoring**: CloudWatch logs, security group logging

## Prerequisites

1. **AWS Account**: Fresh AWS account with appropriate permissions
2. **Terraform**: >= 1.5 installed locally
3. **AWS CLI**: Configured with valid credentials
4. **SSH Key**: Will be created automatically by the bootstrap script
5. **Your Public IP**: You'll need your IP address in CIDR notation (e.g., `203.0.113.45/32`)

### Check Prerequisites

```bash
# Check Terraform version
terraform version

# Check AWS CLI configuration
aws sts get-caller-identity

# Find your public IP
curl -s https://ifconfig.me
```

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform/
terraform init
```

### 2. Copy and Configure Variables

```bash
# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

**IMPORTANT**: Update `terraform.tfvars` with:
- `allowed_ssh_cidr`: Your IP in CIDR notation (e.g., `203.0.113.45/32`)
- `aws_region`: Your preferred AWS region
- `instance_type`: t3.xlarge or other desired type

### 3. Plan Infrastructure

```bash
terraform plan -out=tfplan
```

Review the plan output carefully. Look for:
- 1 VPC, 2 subnets, 1 EC2 instance
- Security groups with restricted SSH access
- IAM role with ECR/CloudWatch/S3 permissions

### 4. Apply Configuration

```bash
terraform apply tfplan
```

This will:
1. Create all AWS resources
2. Launch the EC2 instance with user-data bootstrap script
3. Output important information (IP, SSH command, K3s endpoint)

**Installation Time**: 3-5 minutes for K3s and tools to be fully ready.

### 5. Connect to Workstation

```bash
# Use the SSH command from terraform output
ssh -i ~/.ssh/robo-stack-dev.pem ubuntu@<PUBLIC_IP>

# Or copy the command directly from output
terraform output ssh_command
```

### 6. Verify Installation

```bash
# Check K3s status
sudo systemctl status k3s

# Check nodes
kubectl get nodes

# Check pods
kubectl get pods -A

# View kubeconfig
cat ~/.kube/config
```

## Architecture

```
Internet
    |
    v
[AWS Account: us-east-1]
    |
    v
[VPC: 10.0.0.0/16]
    |
    +---> [Internet Gateway]
    |
    +---> [Public Subnet: 10.0.1.0/24]
    |           |
    |           v
    |     [EC2 Instance: t3.xlarge]
    |     - Ubuntu 22.04 LTS
    |     - K3s (Kubernetes)
    |     - Docker
    |     - Dev Tools
    |     - EBS: 100 GB (gp3)
    |     - IAM Role (ECR, CloudWatch, S3)
    |     - Elastic IP
    |
    +---> [Private Subnet: 10.0.2.0/24]
            (Reserved for future use)

[Security Groups]
- SSH: Your IP/32 only (port 22)
- HTTP: 0.0.0.0/0 (port 80)
- HTTPS: 0.0.0.0/0 (port 443)
- K8s API: 0.0.0.0/0 (port 6443)
- kubectl proxy: 0.0.0.0/0 (port 8001)
- Internal VPC: 10.0.0.0/16 (all traffic)
```

## Outputs

After `terraform apply`, you'll receive:

```
instance_id = "i-0123456789abcdef0"
instance_public_ip = "203.0.113.100"
ssh_command = "ssh -i ~/.ssh/robo-stack-dev.pem ubuntu@203.0.113.100"
k8s_api_endpoint = "https://203.0.113.100:6443"
kubectl_proxy_url = "http://203.0.113.100:8001"
vpc_id = "vpc-0123456789abcdef0"
```

## Usage

### SSH Access

```bash
# Direct connection
ssh -i ~/.ssh/robo-stack-dev.pem ubuntu@<IP>

# With X11 forwarding (if needed)
ssh -i ~/.ssh/robo-stack-dev.pem -X ubuntu@<IP>

# With port forwarding for kubectl proxy
ssh -i ~/.ssh/robo-stack-dev.pem -L 8001:localhost:8001 ubuntu@<IP>
# Then visit http://localhost:8001 in browser
```

### Kubernetes Access

```bash
# From the instance
kubectl get nodes
kubectl get pods -A
kubectl get svc -A

# Port forward a service to local machine
ssh -i ~/.ssh/robo-stack-dev.pem -L 8080:localhost:8080 ubuntu@<IP>
# kubectl port-forward -n default svc/my-app 8080:8080
```

### Docker Access

```bash
# Docker is available and ubuntu user is in docker group
docker ps
docker run --rm -it alpine:latest sh
docker pull <image>
```

### Helm

```bash
# Add Helm repo
helm repo add stable https://charts.helm.sh/stable
helm repo update

# Deploy chart
helm install my-release stable/nginx-ingress
```

## Troubleshooting

### SSH Connection Denied

**Problem**: `Permission denied (publickey)`

**Solution**:
1. Verify key exists: `ls -la ~/.ssh/robo-stack-dev.pem`
2. Check permissions: `chmod 600 ~/.ssh/robo-stack-dev.pem`
3. Verify security group allows your IP: Check `allowed_ssh_cidr` in `terraform.tfvars`
4. Wait 2-3 minutes after apply (security group rules propagate)

### K3s Not Running

**Problem**: `systemctl status k3s` shows inactive

**Solution**:
```bash
ssh -i ~/.ssh/robo-stack-dev.pem ubuntu@<IP>

# Check logs
sudo journalctl -u k3s -n 50

# Check cloud-init logs
tail -f /var/log/cloud-init-output.log

# Manually start (if needed)
sudo systemctl start k3s
sudo systemctl enable k3s
```

### kubeconfig Issues

**Problem**: `kubectl` command not found or kubeconfig invalid

**Solution**:
```bash
ssh -i ~/.ssh/robo-stack-dev.pem ubuntu@<IP>

# Verify kubectl is symlinked
which kubectl
ls -la /usr/local/bin/k3s /usr/local/bin/kubectl

# Check kubeconfig
cat ~/.kube/config

# Force update kubeconfig IP (if using different access method)
sudo k3s kubectl config view --raw > ~/.kube/config
sed -i 's|127.0.0.1|<ACTUAL_IP>|g' ~/.kube/config
```

### EC2 Instance Not Starting

**Problem**: Instance fails to launch or is stuck in "pending"

**Solution**:
1. Check capacity: May be out of capacity in the region/AZ
2. Try different instance type: Change `instance_type` in `terraform.tfvars`
3. Try different region: Change `aws_region`
4. Check account limits: Verify you can launch instances in the region
5. Review CloudTrail logs for errors

### Insufficient Permissions

**Problem**: `terraform apply` fails with "AccessDenied" errors

**Solution**:
1. Verify AWS credentials: `aws sts get-caller-identity`
2. Check IAM permissions: User needs EC2, VPC, IAM, CloudWatch permissions
3. Verify region access: Check if region is enabled in AWS account

### Cloud-init Bootstrap Failed

**Problem**: User-data script didn't complete

**Solution**:
```bash
ssh -i ~/.ssh/robo-stack-dev.pem ubuntu@<IP>

# Check cloud-init logs
tail -100 /var/log/cloud-init-output.log
tail -50 /var/log/robo-stack-init.log

# Check specific services
systemctl status docker
systemctl status k3s
docker ps
k3s kubectl get nodes
```

## Cost Estimation

**Monthly costs** (us-east-1, on-demand):

| Resource | Cost | Notes |
|----------|------|-------|
| t3.xlarge EC2 | $140.98 | 730 hours/month, $0.1932/hour |
| 100GB gp3 EBS | $8.33 | $0.08/GB-month |
| Elastic IP | $0 | Free if in use, $0.005/hour if not associated |
| Data transfer | ~$5 | Minimal outbound (depends on usage) |
| CloudWatch Logs | ~$1 | 7-day retention, minimal logs |
| **Total** | **~$156/month** | Running 24/7 |

**Cost Optimization Tips**:
1. Stop instance when not in use: `aws ec2 stop-instances --instance-ids i-xxx`
2. Use spot instances: Reduce cost by ~70% (add `spot_price` variable)
3. Smaller instance: t3.large ($70/month) if K3s is not heavily used
4. Delete after testing: Run `terraform destroy` to stop all charges

## State Management

### Local State (Current)

State stored in `terraform.tfstate` (local filesystem). **For development only**.

### S3 Backend (Recommended for Teams)

To migrate to S3 backend:

1. Create S3 bucket:
```bash
aws s3api create-bucket \
  --bucket robo-stack-terraform-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket robo-stack-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket robo-stack-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

2. Uncomment S3 backend in `main.tf`

3. Migrate state:
```bash
terraform init
```

## Cleanup & Destruction

### Destroy Everything

```bash
terraform destroy
```

This will:
1. Terminate EC2 instance
2. Delete VPC and subnets
3. Remove security groups and IAM roles
4. Clean up CloudWatch logs
5. Release Elastic IP

**WARNING**: This is irreversible. Make sure you've backed up any important data.

### Partial Destruction

```bash
# Destroy only specific resources
terraform destroy -target aws_instance.workstation

# Destroy everything except VPC (for recovery)
terraform destroy -target aws_ec2.workstation -target aws_iam_role.workstation
```

## Advanced Configuration

### Custom AMI

To use a different base image, modify `data "aws_ami" "ubuntu"` in `ec2.tf`:

```hcl
filter {
  name   = "name"
  values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
}
```

### Spot Instances (Cost Optimization)

Add to `ec2.tf`:

```hcl
spot_price = "0.10"
spot_type  = "persistent"
```

Reduces cost ~70% but instance can be interrupted.

### Additional Storage

Add to `ec2.tf`:

```hcl
ebs_block_device {
  device_name           = "/dev/sdb"
  volume_size           = 200
  volume_type           = "gp3"
  delete_on_termination = true
  encrypted             = true
}
```

### Auto-Scaling Group

For multiple instances, add `asg.tf`:

```hcl
resource "aws_autoscaling_group" "workstations" {
  min_size         = 1
  max_size         = 3
  desired_capacity = 2
  # ... configuration
}
```

## Networking

### Access K8s API from Local

```bash
# Create SSH tunnel
ssh -i ~/.ssh/robo-stack-dev.pem -L 6443:localhost:6443 ubuntu@<IP> -N &

# Add to kubeconfig
kubectl config set-cluster robo-stack \
  --server=https://localhost:6443 \
  --certificate-authority=/path/to/ca.crt

kubectl config set-credentials ubuntu --client-key=... --client-certificate=...
```

### VPN/Private Access

To add private access:
1. Deploy AWS Systems Manager Session Manager
2. Use AWS VPN Client
3. Add NAT Gateway for outbound traffic from private subnet

## Monitoring

### CloudWatch Metrics

View in AWS Console:
- EC2 Dashboard: CPU, Network, Disk I/O
- CloudWatch Logs: `/robo-stack/workstation/*`

### SSH Tunnel for Logs

```bash
# Stream logs from instance
ssh -i ~/.ssh/robo-stack-dev.pem ubuntu@<IP> \
  'tail -f /var/log/cloud-init-output.log'
```

## Maintenance

### Update System

```bash
ssh -i ~/.ssh/robo-stack-dev.pem ubuntu@<IP> \
  'sudo apt-get update && sudo apt-get upgrade -y'
```

### Update K3s

```bash
ssh -i ~/.ssh/robo-stack-dev.pem ubuntu@<IP> \
  'curl -sfL https://get.k3s.io | sh -'
```

### Snapshot Instance

```bash
aws ec2 create-image \
  --instance-id i-0123456789abcdef0 \
  --name "robo-stack-snapshot-$(date +%Y%m%d)" \
  --no-reboot
```

## Security Best Practices

✅ **Implemented**:
- IMDSv2 only (no IMDSv1)
- Encrypted EBS volumes
- Encrypted backup of kubeconfig
- IAM roles (no long-lived credentials)
- Security groups with least-privilege rules
- SSH only from your IP
- Auto-generated SSH keys

⚠️ **Recommended for Production**:
- Enable VPC Flow Logs
- Use AWS Systems Manager Patch Manager
- Deploy AWS Config for compliance
- Enable GuardDuty for threat detection
- Use AWS KMS for encryption keys
- Implement network ACLs for additional security
- Deploy WAF for web traffic
- Use Systems Manager Session Manager instead of SSH

## Support & Issues

### Check Current State

```bash
terraform state list
terraform state show aws_instance.workstation
```

### Refresh State

If state is out of sync with AWS:

```bash
terraform refresh
terraform plan
```

### Debug

Enable debug logging:

```bash
TF_LOG=DEBUG terraform plan
TF_LOG_PATH=/tmp/terraform-debug.log terraform apply
```

## References

- [K3s Documentation](https://docs.k3s.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EC2 User Data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)
- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [Helm Official Docs](https://helm.sh/docs/)

---

**Last Updated**: 2026-03-13
**Terraform Version**: 1.5+
**AWS Provider Version**: 5.40+
**Robo Stack Sprint**: 1

# Robo Stack AWS Terraform - Quick Reference Card

## Pre-Deployment Checklist

```bash
# 1. Verify prerequisites
terraform version          # Must be >= 1.5
aws --version             # Must be configured
aws sts get-caller-identity  # Must return valid credentials

# 2. Get your public IP
curl -s https://ifconfig.me
# Expected output: 203.0.113.45 (or your IP)

# 3. Format for terraform.tfvars
# Add /32 CIDR notation: 203.0.113.45/32
```

## Quick Deploy (3 commands)

```bash
# Option A: Use bootstrap script (recommended)
cd repo/
./scripts/aws-bootstrap.sh
# Follow prompts, enter your IP when asked

# Option B: Manual deployment
cd terraform/
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars                    # Edit: allowed_ssh_cidr
terraform init && terraform plan && terraform apply
```

## Critical Settings (terraform.tfvars)

```hcl
# REQUIRED: Your IP address (NO 0.0.0.0/0!)
allowed_ssh_cidr = "203.0.113.45/32"

# OPTIONAL: Change these if needed
aws_region  = "us-east-1"
instance_type = "t3.xlarge"
```

## After Deployment

```bash
# 1. Get connection info (outputs saved automatically)
terraform output ssh_command

# 2. SSH to instance
ssh -i ~/.ssh/robo-stack-dev.pem ubuntu@<IP>

# 3. Check K3s status (wait 3-5 minutes)
sudo systemctl status k3s
kubectl get nodes
```

## Key Outputs

```bash
# Display all outputs
terraform output

# Get specific values
terraform output instance_public_ip
terraform output ssh_command
terraform output k8s_api_endpoint
```

## SSH Connection

```bash
# Basic connection
ssh -i ~/.ssh/robo-stack-dev.pem ubuntu@<IP>

# With port forwarding (kubectl proxy)
ssh -i ~/.ssh/robo-stack-dev.pem -L 8001:localhost:8001 ubuntu@<IP>

# With X11 forwarding
ssh -i ~/.ssh/robo-stack-dev.pem -X ubuntu@<IP>
```

## Common Kubernetes Commands

```bash
# Connect to instance first:
ssh -i ~/.ssh/robo-stack-dev.pem ubuntu@<IP>

# Then run:
kubectl get nodes            # List nodes
kubectl get pods -A          # List all pods
kubectl get svc -A           # List services
kubectl cluster-info         # Cluster status
k3s kubectl config view      # View kubeconfig
```

## Troubleshooting Quick Fixes

```bash
# SSH connection fails?
# Check security group allows your IP:
aws ec2 describe-security-groups --group-names robo-stack-workstation-sg

# K3s not running?
ssh -i ~/.ssh/robo-stack-dev.pem ubuntu@<IP>
sudo systemctl status k3s
sudo systemctl start k3s
tail -f /var/log/cloud-init-output.log

# kubeconfig issues?
scp -i ~/.ssh/robo-stack-dev.pem ubuntu@<IP>:/home/ubuntu/.kube/config ~/.kube/config-robo
```

## Cost Saving

```bash
# Stop instance (keep EBS volume, keep public IP)
aws ec2 stop-instances --instance-ids <INSTANCE_ID>
# Cost: ~$8/month (EBS only)

# Resume instance
aws ec2 start-instances --instance-ids <INSTANCE_ID>

# Destroy everything (DELETE PERMANENTLY)
terraform destroy
# Cost: $0 (clean slate)
```

## Useful Aliases (already configured)

```bash
# These are pre-configured on the EC2 instance:
k              # kubectl
kgs            # kubectl get svc
kgp            # kubectl get pods
kgd            # kubectl get deployment
kgn            # kubectl get nodes
kdesc          # kubectl describe
kl             # kubectl logs
kex            # kubectl exec -it
k3s-status     # systemctl status k3s
k3s-logs       # journalctl -u k3s -f
```

## Quick Deployment Stats

| Metric | Value |
|--------|-------|
| Deployment Time | ~10 minutes |
| K3s Ready | 3-5 minutes after instance launch |
| Monthly Cost | ~$155 (t3.xlarge, running 24/7) |
| SSH Key | `~/.ssh/robo-stack-dev.pem` |
| Instance Type | t3.xlarge (4 vCPU, 16 GB RAM) |
| Storage | 100 GB gp3 (encrypted) |
| OS | Ubuntu 22.04 LTS |

## Files You'll Need

```
terraform/
├── terraform.tfvars          # YOU CREATE (from .example)
├── .terraform/               # Created by terraform init
├── terraform.tfstate         # Your infrastructure state
├── deployment-info.txt       # Created after apply
└── tfplan-*                  # Plan file (if using manual deploy)
```

## Common Mistakes

❌ **Don't**:
- Set `allowed_ssh_cidr = "0.0.0.0/0"` (opens SSH to world)
- Commit `terraform.tfvars` to git (contains IP)
- Delete `terraform.tfstate` (you'll lose track of resources)
- Stop paying attention to AWS bills (costs $155/month!)

✅ **Do**:
- Use `/32` CIDR for single IP (e.g., `203.0.113.45/32`)
- Keep `terraform.tfvars` local only
- Back up `terraform.tfstate` somewhere safe
- Stop instance when not in use to save costs
- Run `terraform plan` before `apply`

## Support Resources

- **Terraform Docs**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **K3s Docs**: https://docs.k3s.io/
- **AWS EC2 Help**: https://docs.aws.amazon.com/ec2/
- **This Repo's README**: `terraform/README.md`
- **Implementation Guide**: `TERRAFORM_SETUP.md`

## Next Steps After Deployment

1. ✅ Deploy a test application to K3s
2. ✅ Set up kubectl access locally (copy kubeconfig)
3. ✅ Configure AWS credentials on instance (for ECR access)
4. ✅ Test Docker image builds and pushes
5. ✅ Deploy Helm charts to K3s
6. ✅ Configure persistent storage (add EBS volumes)
7. ✅ Set up ingress controller (optional)
8. ✅ Connect to local machine via kubeconfig

---

**Last Updated**: 2026-03-13
**Terraform Version**: 1.5+
**AWS Provider**: 5.40+
**Status**: Production Ready

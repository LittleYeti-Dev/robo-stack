# ============================================================================
# S2.2: Scoped IAM Deploy User
# Replaces root access keys with least-privilege programmatic access
# Sprint 1 Lesson: No root access keys — scoped IAM users only
# ============================================================================

# IAM User for CI/CD and developer programmatic access
resource "aws_iam_user" "deploy" {
  name = "robo-stack-deploy"
  path = "/robo-stack/"

  tags = {
    Name    = "robo-stack-deploy-user"
    Purpose = "Programmatic access for CI/CD and dev operations"
    Sprint  = "2"
  }
}

# Access key for the deploy user
resource "aws_iam_access_key" "deploy" {
  user = aws_iam_user.deploy.name
}

# ── EC2 Management Policy ──────────────────────────────────────────────────
# Start, stop, describe, and reboot the workstation instance
resource "aws_iam_user_policy" "ec2_management" {
  name = "robo-stack-ec2-management"
  user = aws_iam_user.deploy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Describe"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeAddresses",
          "ec2:DescribeImages",
          "ec2:DescribeKeyPairs"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2StartStop"
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RebootInstances"
        ]
        Resource = "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.workstation.id}"
      },
      {
        Sid    = "EC2InstanceConnect"
        Effect = "Allow"
        Action = [
          "ec2-instance-connect:SendSSHPublicKey"
        ]
        Resource = "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.workstation.id}"
      }
    ]
  })
}

# ── ECR Access Policy ──────────────────────────────────────────────────────
# Push and pull container images
resource "aws_iam_user_policy" "ecr_access" {
  name = "robo-stack-ecr-access"
  user = aws_iam_user.deploy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRReadWrite"
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:CreateRepository"
        ]
        Resource = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/robo-stack-*"
      }
    ]
  })
}

# ── S3 Access Policy ──────────────────────────────────────────────────────
# Read/write to robo-stack buckets for state and backups
resource "aws_iam_user_policy" "s3_access" {
  name = "robo-stack-s3-access"
  user = aws_iam_user.deploy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BucketList"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:GetBucketLocation"
        ]
        Resource = "arn:aws:s3:::robo-stack-*"
      },
      {
        Sid    = "S3ObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::robo-stack-*/*"
      }
    ]
  })
}

# ── CloudWatch Access Policy ──────────────────────────────────────────────
# Read metrics and logs for monitoring
resource "aws_iam_user_policy" "cloudwatch_access" {
  name = "robo-stack-cloudwatch-access"
  user = aws_iam_user.deploy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchRead"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAlarms",
          "logs:GetLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# ── Outputs ────────────────────────────────────────────────────────────────
output "deploy_user_arn" {
  description = "ARN of the deploy IAM user"
  value       = aws_iam_user.deploy.arn
}

output "deploy_access_key_id" {
  description = "Access key ID for the deploy user"
  value       = aws_iam_access_key.deploy.id
  sensitive   = true
}

output "deploy_secret_access_key" {
  description = "Secret access key for the deploy user"
  value       = aws_iam_access_key.deploy.secret
  sensitive   = true
}

# ============================================================================
# S2.2: EC2 Auto-Stop — Cost Control
# Automatically stops the EC2 instance after 2 hours of low CPU usage
# Sprint 1 Lesson: EC2 at ~$155/mo needs auto-stop when idle
# ============================================================================

variable "auto_stop_enabled" {
  description = "Enable auto-stop CloudWatch alarm for the EC2 instance"
  type        = bool
  default     = true
}

variable "auto_stop_cpu_threshold" {
  description = "CPU utilization percentage below which instance is considered idle"
  type        = number
  default     = 5
}

variable "auto_stop_evaluation_periods" {
  description = "Number of 15-minute periods below threshold before stopping (8 = 2 hours)"
  type        = number
  default     = 8
}

# ── SNS Topic for Notifications ────────────────────────────────────────────
resource "aws_sns_topic" "ec2_alerts" {
  count = var.auto_stop_enabled ? 1 : 0
  name  = "robo-stack-ec2-alerts"

  tags = {
    Name   = "robo-stack-ec2-alerts"
    Sprint = "2"
  }
}

resource "aws_sns_topic_subscription" "email_alert" {
  count     = var.auto_stop_enabled ? 1 : 0
  topic_arn = aws_sns_topic.ec2_alerts[0].arn
  protocol  = "email"
  endpoint  = "h3ndriks.j@gmail.com"
}

# ── CloudWatch Alarm: Auto-Stop on Idle ────────────────────────────────────
# If CPU stays below 5% for 2 hours (eight 15-minute periods), stop the instance
resource "aws_cloudwatch_metric_alarm" "ec2_idle_stop" {
  count = var.auto_stop_enabled ? 1 : 0

  alarm_name          = "robo-stack-ec2-idle-auto-stop"
  alarm_description   = "Stops EC2 instance when CPU < ${var.auto_stop_cpu_threshold}% for ${var.auto_stop_evaluation_periods * 15} minutes"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.auto_stop_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 900 # 15 minutes
  statistic           = "Average"
  threshold           = var.auto_stop_cpu_threshold

  dimensions = {
    InstanceId = aws_instance.workstation.id
  }

  # Auto-stop action
  alarm_actions = [
    "arn:aws:automate:${data.aws_region.current.name}:ec2:stop",
    var.auto_stop_enabled ? aws_sns_topic.ec2_alerts[0].arn : ""
  ]

  # Notify when instance becomes active again
  ok_actions = [
    var.auto_stop_enabled ? aws_sns_topic.ec2_alerts[0].arn : ""
  ]

  treat_missing_data = "notBreaching"

  tags = {
    Name   = "robo-stack-idle-stop-alarm"
    Sprint = "2"
  }
}

# ── CloudWatch Alarm: High CPU Warning ─────────────────────────────────────
# Alert when CPU sustains above 80% for 30 minutes (potential issues)
resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu" {
  count = var.auto_stop_enabled ? 1 : 0

  alarm_name          = "robo-stack-ec2-high-cpu-warning"
  alarm_description   = "Warning: EC2 CPU sustained above 80% for 30 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 900
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    InstanceId = aws_instance.workstation.id
  }

  alarm_actions = [
    var.auto_stop_enabled ? aws_sns_topic.ec2_alerts[0].arn : ""
  ]

  treat_missing_data = "notBreaching"

  tags = {
    Name   = "robo-stack-high-cpu-alarm"
    Sprint = "2"
  }
}

# ── Outputs ────────────────────────────────────────────────────────────────
output "auto_stop_alarm_arn" {
  description = "ARN of the auto-stop CloudWatch alarm"
  value       = var.auto_stop_enabled ? aws_cloudwatch_metric_alarm.ec2_idle_stop[0].arn : "disabled"
}

output "sns_topic_arn" {
  description = "ARN of the EC2 alerts SNS topic"
  value       = var.auto_stop_enabled ? aws_sns_topic.ec2_alerts[0].arn : "disabled"
}

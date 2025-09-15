# CloudWatch Module - Outputs

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.etl_dashboard.dashboard_name}"
}

output "log_group_names" {
  description = "Names of the CloudWatch log groups"
  value       = { for k, v in aws_cloudwatch_log_group.lambda_logs : k => v.name }
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "alarm_names" {
  description = "Names of the CloudWatch alarms"
  value = {
    lambda_errors   = { for k, v in aws_cloudwatch_metric_alarm.lambda_errors : k => v.alarm_name }
    lambda_duration = { for k, v in aws_cloudwatch_metric_alarm.lambda_duration : k => v.alarm_name }
    sqs_queue_depth = aws_cloudwatch_metric_alarm.sqs_queue_depth.alarm_name
  }
}

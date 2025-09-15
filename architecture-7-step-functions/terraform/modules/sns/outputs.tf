# SNS Module Outputs

output "topic_arns" {
  description = "ARNs of the SNS topics"
  value       = { for k, v in aws_sns_topic.topics : k => v.arn }
}

output "topic_names" {
  description = "Names of the SNS topics"
  value       = { for k, v in aws_sns_topic.topics : k => v.name }
}

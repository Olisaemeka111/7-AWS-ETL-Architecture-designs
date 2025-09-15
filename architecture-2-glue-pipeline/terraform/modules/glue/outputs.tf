# Glue Module - Outputs

output "job_names" {
  description = "Names of the created Glue jobs"
  value       = { for k, v in aws_glue_job.jobs : k => v.name }
}

output "crawler_names" {
  description = "Names of the created Glue crawlers"
  value       = { for k, v in aws_glue_crawler.crawlers : k => v.name }
}

output "database_names" {
  description = "Names of the created Glue databases"
  value       = { for k, v in aws_glue_catalog_database.databases : k => v.name }
}

output "workflow_name" {
  description = "Name of the created Glue workflow"
  value       = aws_glue_workflow.main_workflow.name
}

output "glue_crawler_role_arn" {
  description = "ARN of the Glue crawler IAM role"
  value       = aws_iam_role.glue_crawler_role.arn
}

output "glue_job_role_arn" {
  description = "ARN of the Glue job IAM role"
  value       = aws_iam_role.glue_job_role.arn
}

output "security_configuration_name" {
  description = "Name of the Glue security configuration"
  value       = aws_glue_security_configuration.main.name
}

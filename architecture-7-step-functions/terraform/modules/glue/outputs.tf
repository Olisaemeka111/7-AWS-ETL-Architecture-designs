# Glue Module Outputs

output "job_names" {
  description = "Names of the Glue jobs"
  value       = { for k, v in aws_glue_job.jobs : k => v.name }
}

output "job_arns" {
  description = "ARNs of the Glue jobs"
  value       = { for k, v in aws_glue_job.jobs : k => v.arn }
}

output "crawler_names" {
  description = "Names of the Glue crawlers"
  value       = { for k, v in aws_glue_crawler.crawlers : k => v.name }
}

output "database_names" {
  description = "Names of the Glue databases"
  value       = { for k, v in aws_glue_catalog_database.databases : k => v.name }
}

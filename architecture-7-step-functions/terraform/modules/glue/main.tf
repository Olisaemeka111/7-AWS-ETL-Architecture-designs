# Glue Module for Step Functions ETL

# Glue Jobs
resource "aws_glue_job" "jobs" {
  for_each = var.glue_jobs

  name         = each.value.name
  role_arn     = var.iam_role_arn
  glue_version = each.value.glue_version
  max_capacity = each.value.max_capacity
  timeout      = each.value.timeout

  command {
    script_location = each.value.script_path
    python_version  = "3"
  }

  tags = var.tags
}

# Glue Crawlers
resource "aws_glue_crawler" "crawlers" {
  for_each = var.crawlers

  name          = each.value.name
  role          = var.iam_role_arn
  database_name = each.value.database_name
  schedule      = each.value.schedule

  s3_target {
    path = each.value.s3_targets[0]
  }

  tags = var.tags
}

# Glue Databases
resource "aws_glue_catalog_database" "databases" {
  for_each = toset([for crawler in var.crawlers : crawler.database_name])

  name = each.value

  tags = var.tags
}

# Note: IAM role and policies are managed by the IAM module

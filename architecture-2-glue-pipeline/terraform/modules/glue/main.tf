# Glue Module - Main Configuration

# Glue Data Catalog Databases
resource "aws_glue_catalog_database" "databases" {
  for_each = toset([
    "${var.project_name}_${var.environment}_source_db",
    "${var.project_name}_${var.environment}_clean_db",
    "${var.project_name}_${var.environment}_aggregated_db"
  ])
  
  name        = each.key
  description = "Glue database for ${each.key}"
  
  tags = var.tags
}

# Glue Connection for external data sources
resource "aws_glue_connection" "external_connections" {
  for_each = var.source_databases
  
  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:${each.value.type}://${each.value.host}:${each.value.port}/${each.value.database}"
    USERNAME            = each.value.username
    PASSWORD            = each.value.password
  }
  
  name        = "${var.project_name}-${var.environment}-${each.key}-connection"
  description = each.value.description
  
  physical_connection_requirements {
    availability_zone      = data.aws_availability_zones.available.names[0]
    security_group_id_list = var.security_group_ids
    subnet_id              = var.private_subnet_ids[0]
  }
  
  tags = var.tags
}

# Glue Crawlers
resource "aws_glue_crawler" "crawlers" {
  for_each = var.crawlers
  
  name          = each.value.name
  role          = aws_iam_role.glue_crawler_role.arn
  database_name = each.value.database_name
  
  s3_target {
    path = each.value.s3_targets[0]
  }
  
  schedule = each.value.schedule
  
  tags = var.tags
}

# Glue ETL Jobs
resource "aws_glue_job" "jobs" {
  for_each = var.glue_jobs
  
  name              = each.value.name
  role_arn          = aws_iam_role.glue_job_role.arn
  glue_version      = each.value.glue_version
  max_capacity      = each.value.max_capacity
  timeout           = each.value.timeout
  max_retries       = 2
  
  command {
    script_location = each.value.script_path
    python_version  = "3"
  }
  
  default_arguments = {
    "--job-language"                    = "python"
    "--job-bookmark-option"            = "job-bookmark-enable"
    "--enable-metrics"                 = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                = "true"
    "--spark-event-logs-path"          = "s3://${var.logs_zone_bucket}/spark-logs/"
    "--TempDir"                        = "s3://${var.temp_zone_bucket}/"
    "--enable-glue-datacatalog"        = "true"
    "--additional-python-modules"      = "pandas==1.5.3,pyarrow==10.0.1"
    "--conf"                           = "spark.sql.adaptive.enabled=true,spark.sql.adaptive.coalescePartitions.enabled=true"
  }
  
  tags = var.tags
}

# Glue Workflow
resource "aws_glue_workflow" "main_workflow" {
  name        = "${var.project_name}-${var.environment}-main-workflow"
  description = "Main ETL workflow for ${var.project_name}"
  
  tags = var.tags
}

# Glue Triggers
resource "aws_glue_trigger" "schedule_trigger" {
  name          = "${var.project_name}-${var.environment}-schedule-trigger"
  type          = "SCHEDULED"
  schedule      = "cron(0 2 * * ? *)"  # Daily at 2 AM
  workflow_name = aws_glue_workflow.main_workflow.name
  
  actions {
    job_name = aws_glue_job.jobs["extract-job"].name
  }
  
  tags = var.tags
}

resource "aws_glue_trigger" "conditional_triggers" {
  for_each = {
    "transform-trigger" = {
      job_name = "transform-job"
      condition = "SUCCEEDED"
    }
    "load-trigger" = {
      job_name = "load-job"
      condition = "SUCCEEDED"
    }
  }
  
  name          = "${var.project_name}-${var.environment}-${each.key}"
  type          = "CONDITIONAL"
  workflow_name = aws_glue_workflow.main_workflow.name
  
  predicate {
    conditions {
      job_name = aws_glue_job.jobs[each.value.job_name].name
      state    = each.value.condition
    }
  }
  
  actions {
    job_name = aws_glue_job.jobs[each.value.job_name].name
  }
  
  tags = var.tags
}

# Glue Security Configuration
resource "aws_glue_security_configuration" "main" {
  name = "${var.project_name}-${var.environment}-security-config"
  
  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "SSE-KMS"
      kms_key_arn               = var.kms_key_arn
    }
    
    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "CSE-KMS"
      kms_key_arn                  = var.kms_key_arn
    }
    
    s3_encryption {
      s3_encryption_mode = "SSE-KMS"
      kms_key_arn        = var.kms_key_arn
    }
  }
  
  tags = var.tags
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# IAM Role for Glue Crawler
resource "aws_iam_role" "glue_crawler_role" {
  name = "${var.project_name}-${var.environment}-glue-crawler-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "glue_crawler_service_role" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_crawler_s3_policy" {
  name = "${var.project_name}-${var.environment}-glue-crawler-s3-policy"
  role = aws_iam_role.glue_crawler_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.raw_zone_bucket}",
          "arn:aws:s3:::${var.raw_zone_bucket}/*",
          "arn:aws:s3:::${var.clean_zone_bucket}",
          "arn:aws:s3:::${var.clean_zone_bucket}/*",
          "arn:aws:s3:::${var.aggregated_zone_bucket}",
          "arn:aws:s3:::${var.aggregated_zone_bucket}/*"
        ]
      }
    ]
  })
}

# IAM Role for Glue Jobs
resource "aws_iam_role" "glue_job_role" {
  name = "${var.project_name}-${var.environment}-glue-job-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "glue_job_service_role" {
  role       = aws_iam_role.glue_job_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_job_s3_policy" {
  name = "${var.project_name}-${var.environment}-glue-job-s3-policy"
  role = aws_iam_role.glue_job_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.raw_zone_bucket}",
          "arn:aws:s3:::${var.raw_zone_bucket}/*",
          "arn:aws:s3:::${var.clean_zone_bucket}",
          "arn:aws:s3:::${var.clean_zone_bucket}/*",
          "arn:aws:s3:::${var.aggregated_zone_bucket}",
          "arn:aws:s3:::${var.aggregated_zone_bucket}/*",
          "arn:aws:s3:::${var.temp_zone_bucket}",
          "arn:aws:s3:::${var.temp_zone_bucket}/*",
          "arn:aws:s3:::${var.logs_zone_bucket}",
          "arn:aws:s3:::${var.logs_zone_bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "glue_job_glue_policy" {
  name = "${var.project_name}-${var.environment}-glue-job-glue-policy"
  role = aws_iam_role.glue_job_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:GetTable",
          "glue:GetDatabase",
          "glue:GetPartitions",
          "glue:GetTableVersion",
          "glue:GetTableVersions"
        ]
        Resource = "*"
      }
    ]
  })
}

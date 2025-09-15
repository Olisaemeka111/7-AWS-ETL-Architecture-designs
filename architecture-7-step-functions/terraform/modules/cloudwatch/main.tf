# CloudWatch Module for Step Functions ETL

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "etl_dashboard" {
  dashboard_name = "${var.project_name}-${var.environment}-etl-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            for func_name in var.lambda_function_names : [
              "AWS/Lambda",
              "Invocations",
              "FunctionName",
              func_name
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda Invocations"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            for func_name in var.lambda_function_names : [
              "AWS/Lambda",
              "Errors",
              "FunctionName",
              func_name
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda Errors"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            for func_name in var.lambda_function_names : [
              "AWS/Lambda",
              "Duration",
              "FunctionName",
              func_name
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda Duration"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/States", "ExecutionsStarted", "StateMachineArn", var.step_functions_state_machine_arn],
            ["AWS/States", "ExecutionsSucceeded", "StateMachineArn", var.step_functions_state_machine_arn],
            ["AWS/States", "ExecutionsFailed", "StateMachineArn", var.step_functions_state_machine_arn]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Step Functions Executions"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            for bucket_name in var.s3_bucket_names : [
              "AWS/S3",
              "BucketSizeBytes",
              "BucketName",
              bucket_name,
              "StorageType",
              "StandardStorage"
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "S3 Bucket Size"
          period  = 86400
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            for bucket_name in var.s3_bucket_names : [
              "AWS/S3",
              "NumberOfObjects",
              "BucketName",
              bucket_name,
              "StorageType",
              "AllStorageTypes"
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "S3 Number of Objects"
          period  = 86400
        }
      }
    ]
  })

}

# CloudWatch Alarms for Lambda Functions
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = toset(var.lambda_function_names)

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors lambda errors for ${each.key}"
  alarm_actions       = var.sns_topic_arns

  dimensions = {
    FunctionName = each.key
  }

}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = toset(var.lambda_function_names)

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "300000" # 5 minutes in milliseconds
  alarm_description   = "This metric monitors lambda duration for ${each.key}"
  alarm_actions       = var.sns_topic_arns

  dimensions = {
    FunctionName = each.key
  }

}

# CloudWatch Alarms for Step Functions
resource "aws_cloudwatch_metric_alarm" "step_functions_failures" {
  alarm_name          = "${var.project_name}-${var.environment}-step-functions-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors step functions failures"
  alarm_actions       = var.sns_topic_arns

  dimensions = {
    StateMachineArn = var.step_functions_state_machine_arn
  }

}

# CloudWatch Alarms for S3
resource "aws_cloudwatch_metric_alarm" "s3_errors" {
  for_each = toset(var.s3_bucket_names)

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrors"
  namespace           = "AWS/S3"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors S3 4xx errors for ${each.key}"
  alarm_actions       = var.sns_topic_arns

  dimensions = {
    BucketName = each.key
  }

}

# CloudWatch Alarms for Glue Jobs
resource "aws_cloudwatch_metric_alarm" "glue_job_failures" {
  for_each = toset(var.glue_job_names)

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "glue.driver.aggregate.numFailedTasks"
  namespace           = "AWS/Glue"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors Glue job failures for ${each.key}"
  alarm_actions       = var.sns_topic_arns

  dimensions = {
    JobName = each.key
  }

}

# CloudWatch Alarms for EMR (if enabled)
resource "aws_cloudwatch_metric_alarm" "emr_cluster_failures" {
  count = var.emr_cluster_id != null ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-emr-cluster-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "IsHealthy"
  namespace           = "AWS/ElasticMapReduce"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors EMR cluster health"
  alarm_actions       = var.sns_topic_arns

  dimensions = {
    JobFlowId = var.emr_cluster_id
  }

}

# CloudWatch Alarms for Redshift (if enabled)
resource "aws_cloudwatch_metric_alarm" "redshift_cluster_health" {
  count = var.redshift_cluster_identifier != null ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-redshift-cluster-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthStatus"
  namespace           = "AWS/Redshift"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors Redshift cluster health"
  alarm_actions       = var.sns_topic_arns

  dimensions = {
    ClusterIdentifier = var.redshift_cluster_identifier
  }

}

# Data source for current region
data "aws_region" "current" {}

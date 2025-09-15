# Architecture 1: Serverless ETL with Lambda

## Overview
This architecture implements a serverless ETL pipeline using AWS Lambda functions for data processing, orchestrated by EventBridge, with SQS for decoupling and error handling.

## Components
- **Data Sources**: RDS, S3, APIs, SaaS platforms
- **Processing**: AWS Lambda functions
- **Orchestration**: Amazon EventBridge
- **Queue**: Amazon SQS for decoupling
- **Storage**: Amazon S3 (staging) → Amazon Redshift (warehouse)
- **Monitoring**: CloudWatch Logs and Metrics

## Architecture Flow
1. EventBridge triggers Lambda on schedule or events
2. Lambda extracts data from various sources
3. Data transformation logic in Lambda
4. Transformed data staged in S3
5. Lambda loads data into Redshift
6. Error handling via SQS dead letter queues

## Benefits
- No server management
- Automatic scaling
- Pay-per-execution pricing
- Quick deployment and iteration

## Use Cases
- Small to medium data volumes (<15 minutes processing)
- Event-driven data pipelines
- Simple transformations
- Cost-sensitive environments

## Deployment
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Cost Estimation
- Lambda: ~$0.20 per 1M requests + compute time
- S3: ~$0.023 per GB stored
- Redshift: ~$0.25 per hour for dc2.large
- SQS: ~$0.40 per 1M requests

## Monitoring
- CloudWatch dashboards for pipeline metrics
- SQS dead letter queue monitoring
- Lambda error rates and duration
- Redshift query performance

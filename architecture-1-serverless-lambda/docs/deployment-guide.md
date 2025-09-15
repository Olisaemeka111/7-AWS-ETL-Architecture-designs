# Architecture 1: Serverless ETL with Lambda - Deployment Guide

## Prerequisites

### AWS Account Setup
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Python 3.9+ for Lambda functions
- Access to AWS services: Lambda, S3, Redshift, SQS, EventBridge, CloudWatch

### Required IAM Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:*",
                "s3:*",
                "redshift:*",
                "sqs:*",
                "events:*",
                "cloudwatch:*",
                "iam:*",
                "vpc:*",
                "rds:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## Deployment Steps

### 1. Clone and Setup
```bash
cd architecture-1-serverless-lambda
```

### 2. Configure Variables
Edit `terraform/variables.tf` with your specific values:
```hcl
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "etl-serverless"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
```

### 3. Initialize Terraform
```bash
cd terraform
terraform init
```

### 4. Plan Deployment
```bash
terraform plan -var-file="terraform.tfvars"
```

### 5. Deploy Infrastructure
```bash
terraform apply -var-file="terraform.tfvars"
```

### 6. Deploy Lambda Functions
```bash
# Package and deploy extract function
cd ../src/lambda/extract
pip install -r requirements.txt -t .
zip -r extract.zip .
aws lambda update-function-code --function-name etl-extract --zip-file fileb://extract.zip

# Package and deploy transform function
cd ../transform
pip install -r requirements.txt -t .
zip -r transform.zip .
aws lambda update-function-code --function-name etl-transform --zip-file fileb://transform.zip

# Package and deploy load function
cd ../load
pip install -r requirements.txt -t .
zip -r load.zip .
aws lambda update-function-code --function-name etl-load --zip-file fileb://load.zip
```

## Configuration

### Environment Variables
Set the following environment variables for your Lambda functions:

```bash
# Extract Lambda
aws lambda update-function-configuration \
  --function-name etl-extract \
  --environment Variables='{
    "SQS_QUEUE_URL":"https://sqs.us-east-1.amazonaws.com/123456789012/etl-queue",
    "S3_BUCKET":"etl-staging-bucket",
    "RDS_ENDPOINT":"your-rds-endpoint.amazonaws.com"
  }'

# Transform Lambda
aws lambda update-function-configuration \
  --function-name etl-transform \
  --environment Variables='{
    "S3_BUCKET":"etl-staging-bucket",
    "SQS_QUEUE_URL":"https://sqs.us-east-1.amazonaws.com/123456789012/etl-queue"
  }'

# Load Lambda
aws lambda update-function-configuration \
  --function-name etl-load \
  --environment Variables='{
    "S3_BUCKET":"etl-staging-bucket",
    "REDSHIFT_ENDPOINT":"your-redshift-cluster.amazonaws.com",
    "REDSHIFT_DATABASE":"etl_warehouse"
  }'
```

### EventBridge Rules
Create scheduled rules for data extraction:

```bash
# Daily extraction at 2 AM UTC
aws events put-rule \
  --name "etl-daily-extract" \
  --schedule-expression "cron(0 2 * * ? *)" \
  --description "Daily ETL extraction"

# Add Lambda target
aws events put-targets \
  --rule "etl-daily-extract" \
  --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:123456789012:function:etl-extract"
```

## Testing

### 1. Test Individual Components
```bash
# Test extract function
aws lambda invoke \
  --function-name etl-extract \
  --payload '{"test": true}' \
  response.json

# Test transform function
aws lambda invoke \
  --function-name etl-transform \
  --payload '{"test": true}' \
  response.json

# Test load function
aws lambda invoke \
  --function-name etl-load \
  --payload '{"test": true}' \
  response.json
```

### 2. Test End-to-End Pipeline
```bash
# Trigger the pipeline manually
aws events put-events \
  --entries '[
    {
      "Source": "etl.manual",
      "DetailType": "ETL Pipeline Trigger",
      "Detail": "{\"trigger\": \"manual\"}"
    }
  ]'
```

## Monitoring Setup

### 1. CloudWatch Dashboard
```bash
# Create dashboard
aws cloudwatch put-dashboard \
  --dashboard-name "ETL-Pipeline-Monitoring" \
  --dashboard-body file://monitoring/cloudwatch-dashboard.json
```

### 2. Alarms
```bash
# Lambda error rate alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "ETL-Lambda-ErrorRate" \
  --alarm-description "ETL Lambda error rate too high" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold

# SQS queue depth alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "ETL-SQS-QueueDepth" \
  --alarm-description "ETL SQS queue too deep" \
  --metric-name ApproximateNumberOfVisibleMessages \
  --namespace AWS/SQS \
  --statistic Average \
  --period 300 \
  --threshold 100 \
  --comparison-operator GreaterThanThreshold
```

## Troubleshooting

### Common Issues

#### 1. Lambda Timeout
- Increase timeout in Lambda configuration
- Optimize code for better performance
- Consider breaking large operations into smaller chunks

#### 2. SQS Message Visibility
- Adjust visibility timeout based on Lambda execution time
- Implement proper error handling in Lambda functions

#### 3. Redshift Connection Issues
- Verify security groups allow Lambda to connect to Redshift
- Check VPC configuration and subnet groups
- Ensure proper IAM roles for cross-service access

#### 4. S3 Access Denied
- Verify bucket policies allow Lambda access
- Check IAM roles have necessary S3 permissions
- Ensure bucket exists and is in correct region

### Debugging Steps

1. **Check CloudWatch Logs**
   ```bash
   aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/etl-"
   aws logs get-log-events --log-group-name "/aws/lambda/etl-extract" --log-stream-name "latest"
   ```

2. **Monitor SQS Metrics**
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/SQS \
     --metric-name ApproximateNumberOfVisibleMessages \
     --dimensions Name=QueueName,Value=etl-queue \
     --start-time 2024-01-01T00:00:00Z \
     --end-time 2024-01-01T23:59:59Z \
     --period 300 \
     --statistics Average
   ```

3. **Test Redshift Connectivity**
   ```bash
   # From Lambda VPC, test connection
   psql -h your-redshift-cluster.amazonaws.com -p 5439 -U username -d database
   ```

## Rollback Procedures

### 1. Infrastructure Rollback
```bash
# Revert to previous Terraform state
terraform plan -var-file="terraform.tfvars.backup"
terraform apply -var-file="terraform.tfvars.backup"
```

### 2. Lambda Function Rollback
```bash
# Deploy previous version
aws lambda update-function-code \
  --function-name etl-extract \
  --zip-file fileb://extract-previous.zip
```

### 3. Data Recovery
```bash
# Restore from S3 backup
aws s3 cp s3://etl-backup-bucket/backup-date/ s3://etl-staging-bucket/ --recursive
```

## Security Considerations

### 1. Encryption
- Enable encryption at rest for S3 and Redshift
- Use AWS KMS for key management
- Enable encryption in transit for all communications

### 2. Access Control
- Implement least privilege IAM policies
- Use VPC endpoints for private communication
- Enable CloudTrail for audit logging

### 3. Network Security
- Deploy Lambda in private subnets
- Use security groups to restrict access
- Implement VPC flow logs for monitoring

## Performance Optimization

### 1. Lambda Optimization
- Right-size memory allocation
- Use provisioned concurrency for consistent performance
- Implement connection pooling for database connections

### 2. S3 Optimization
- Use appropriate storage classes
- Implement lifecycle policies
- Use multipart uploads for large files

### 3. Redshift Optimization
- Choose appropriate node types
- Implement proper distribution and sort keys
- Use compression for better performance

## Maintenance

### 1. Regular Tasks
- Monitor costs and optimize resources
- Update Lambda runtime versions
- Review and rotate access keys
- Update security patches

### 2. Backup Strategy
- Regular S3 bucket backups
- Redshift cluster snapshots
- Terraform state backups
- Configuration backups

### 3. Scaling Considerations
- Monitor queue depth and Lambda concurrency
- Implement auto-scaling for high-volume periods
- Consider moving to larger Redshift nodes if needed

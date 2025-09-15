# Architecture 7: Step Functions ETL - Deployment Guide

## Prerequisites

### AWS Account Setup
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Python 3.9+ for Lambda functions
- Access to AWS services: Step Functions, Lambda, Glue, EMR, S3, EventBridge, IAM, CloudWatch, SNS

### Required IAM Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "states:*",
                "lambda:*",
                "glue:*",
                "emr:*",
                "s3:*",
                "events:*",
                "iam:*",
                "cloudwatch:*",
                "logs:*",
                "sns:*",
                "secretsmanager:*",
                "redshift:*"
            ],
            "Resource": "*"
        }
    ]
}
```

### Local Environment Setup
```bash
# Install Terraform
brew install terraform

# Install AWS CLI
brew install awscli

# Install Python 3.9+
brew install python@3.9

# Configure AWS CLI
aws configure

# Verify installation
terraform version
aws --version
python3 --version
```

## Deployment Steps

### 1. Clone and Navigate to Architecture 7
```bash
cd architecture-7-step-functions
```

### 2. Configure Variables
Create a `terraform.tfvars` file:
```hcl
# General Configuration
project_name = "step-functions-etl"
environment  = "dev"
aws_region   = "us-east-1"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"

# Lambda Configuration
lambda_timeout = 300
lambda_memory_size = 1024
lambda_runtime = "python3.9"

# Glue Configuration
glue_max_capacity = 2
glue_timeout = 60
glue_version = "4.0"

# EMR Configuration (Optional)
enable_emr = false
emr_release_label = "emr-6.15.0"
emr_master_instance_type = "m5.xlarge"
emr_core_instance_type = "m5.xlarge"
emr_core_instance_count = 2

# Redshift Configuration
enable_redshift = true
redshift_node_type = "dc2.large"
redshift_number_of_nodes = 1
redshift_database_name = "step_functions_warehouse"
redshift_master_username = "admin"
redshift_master_password = "YourSecurePassword123!"

# Step Functions Configuration
step_functions_type = "STANDARD"
step_functions_logging_level = "ERROR"
step_functions_tracing_enabled = true

# ETL Configuration
etl_schedule_expression = "rate(1 hour)"
etl_batch_size = 1000
etl_max_retries = 3
etl_retry_delay = 5

# Notification Configuration
alert_email = "alerts@example.com"
notification_email = "notifications@example.com"

# Monitoring Configuration
enable_detailed_monitoring = true
log_retention_days = 14
enable_xray_tracing = true

# Security Configuration
enable_encryption = true

# Performance Configuration
enable_auto_scaling = true
enable_spot_instances = false
spot_instance_percentage = 0

# Cost Optimization
enable_cost_optimization = true
reserved_capacity_enabled = false

# Data Quality Configuration
enable_data_quality_checks = true
data_quality_threshold = 95

# Disaster Recovery Configuration
enable_disaster_recovery = false
backup_retention_days = 7
```

### 3. Initialize Terraform
```bash
cd terraform
terraform init
```

### 4. Plan Deployment
```bash
terraform plan -var-file="../terraform.tfvars"
```

### 5. Deploy Infrastructure
```bash
terraform apply -var-file="../terraform.tfvars"
```

### 6. Verify Deployment
```bash
# Check Step Functions state machine
aws stepfunctions list-state-machines --query 'stateMachines[*].[name,stateMachineArn]' --output table

# Check Lambda functions
aws lambda list-functions --query 'Functions[*].[FunctionName,Runtime,LastModified]' --output table

# Check Glue jobs
aws glue get-jobs --query 'JobList[*].[Name,Role,LastModifiedOn]' --output table

# Check S3 buckets
aws s3 ls

# Check SNS topics
aws sns list-topics --query 'Topics[*].TopicArn' --output table
```

## Post-Deployment Configuration

### 1. Set Up Secrets
```bash
# Create secrets for API keys and passwords
aws secretsmanager create-secret \
    --name "etl/api-key" \
    --description "API key for ETL extraction" \
    --secret-string "your-api-key-here"

aws secretsmanager create-secret \
    --name "etl/redshift-password" \
    --description "Redshift password" \
    --secret-string "YourSecurePassword123!"
```

### 2. Upload Lambda Function Code
```bash
# Create deployment packages
cd src/lambda
zip -r extract.zip extract.py
zip -r transform.zip transform.py
zip -r validate.zip validate.py
zip -r load.zip load.py
zip -r error_handler.zip error_handler.py

# Upload to S3
aws s3 cp extract.zip s3://your-logs-bucket/lambda-functions/
aws s3 cp transform.zip s3://your-logs-bucket/lambda-functions/
aws s3 cp validate.zip s3://your-logs-bucket/lambda-functions/
aws s3 cp load.zip s3://your-logs-bucket/lambda-functions/
aws s3 cp error_handler.zip s3://your-logs-bucket/lambda-functions/

# Update Lambda function code
aws lambda update-function-code \
    --function-name "step-functions-etl-dev-etl-extract" \
    --s3-bucket "your-logs-bucket" \
    --s3-key "lambda-functions/extract.zip"

aws lambda update-function-code \
    --function-name "step-functions-etl-dev-etl-transform" \
    --s3-bucket "your-logs-bucket" \
    --s3-key "lambda-functions/transform.zip"

aws lambda update-function-code \
    --function-name "step-functions-etl-dev-etl-validate" \
    --s3-bucket "your-logs-bucket" \
    --s3-key "lambda-functions/validate.zip"

aws lambda update-function-code \
    --function-name "step-functions-etl-dev-etl-load" \
    --s3-bucket "your-logs-bucket" \
    --s3-key "lambda-functions/load.zip"

aws lambda update-function-code \
    --function-name "step-functions-etl-dev-etl-error-handler" \
    --s3-bucket "your-logs-bucket" \
    --s3-key "lambda-functions/error_handler.zip"
```

### 3. Upload Glue Job Scripts
```bash
# Create Glue job script
cat > transform_job.py << 'EOF'
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

# Initialize Glue context
glueContext = GlueContext(SparkContext.getOrCreate())
spark = glueContext.spark_session
job = Job(glueContext)

# Get job parameters
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'raw_data_bucket', 'processed_data_bucket'])
job.init(args['JOB_NAME'], args)

# Read data from S3
raw_data = glueContext.create_dynamic_frame.from_options(
    connection_type="s3",
    connection_options={"paths": [f"s3://{args['raw_data_bucket']}/"]},
    format="parquet"
)

# Transform data
transformed_data = raw_data.toDF()

# Apply transformations
transformed_data = transformed_data.filter(transformed_data.id.isNotNull())
transformed_data = transformed_data.withColumn("processed_at", current_timestamp())

# Write to S3
glueContext.write_dynamic_frame.from_options(
    frame=DynamicFrame.fromDF(transformed_data, glueContext, "transformed_data"),
    connection_type="s3",
    connection_options={"path": f"s3://{args['processed_data_bucket']}/"},
    format="parquet"
)

job.commit()
EOF

# Upload to S3
aws s3 cp transform_job.py s3://your-logs-bucket/scripts/
```

### 4. Set Up EventBridge Rules
```bash
# Create ETL schedule rule
aws events put-rule \
    --name "step-functions-etl-dev-etl-schedule" \
    --schedule-expression "rate(1 hour)" \
    --description "Schedule ETL jobs"

# Add Step Functions target
aws events put-targets \
    --rule "step-functions-etl-dev-etl-schedule" \
    --targets "Id"="1","Arn"="arn:aws:states:region:account:stateMachine:step-functions-etl-dev-etl-state-machine"
```

### 5. Configure SNS Subscriptions
```bash
# Subscribe to ETL alerts topic
aws sns subscribe \
    --topic-arn "arn:aws:sns:region:account:step-functions-etl-dev-etl-alerts" \
    --protocol email \
    --notification-endpoint "alerts@example.com"

# Subscribe to ETL notifications topic
aws sns subscribe \
    --topic-arn "arn:aws:sns:region:account:step-functions-etl-dev-etl-notifications" \
    --protocol email \
    --notification-endpoint "notifications@example.com"
```

## Data Processing Workflow

### 1. Manual ETL Execution
```bash
# Start Step Functions execution
aws stepfunctions start-execution \
    --state-machine-arn "arn:aws:states:region:account:stateMachine:step-functions-etl-dev-etl-state-machine" \
    --name "etl-execution-$(date +%Y%m%d-%H%M%S)" \
    --input '{
        "extraction_config": {
            "type": "s3",
            "bucket": "step-functions-etl-dev-raw-data",
            "prefix": "source-data/",
            "format": "parquet"
        },
        "output_config": {
            "bucket": "step-functions-etl-dev-processed-data",
            "key": "extracted-data/data.parquet",
            "format": "parquet"
        }
    }'
```

### 2. Monitor Execution
```bash
# List executions
aws stepfunctions list-executions \
    --state-machine-arn "arn:aws:states:region:account:stateMachine:step-functions-etl-dev-etl-state-machine"

# Describe execution
aws stepfunctions describe-execution \
    --execution-arn "arn:aws:states:region:account:execution:step-functions-etl-dev-etl-state-machine:execution-id"

# Get execution history
aws stepfunctions get-execution-history \
    --execution-arn "arn:aws:states:region:account:execution:step-functions-etl-dev-etl-state-machine:execution-id"
```

### 3. Data Validation
```bash
# Check processed data in S3
aws s3 ls s3://step-functions-etl-dev-processed-data/ --recursive

# Check Glue crawler results
aws glue get-crawler --name "step-functions-etl-dev-processed-data-crawler"
aws glue get-crawler-metrics --crawler-name "step-functions-etl-dev-processed-data-crawler"
```

## Monitoring and Troubleshooting

### 1. CloudWatch Monitoring
```bash
# View CloudWatch dashboard
aws cloudwatch get-dashboard --dashboard-name "Step-Functions-ETL-Dashboard"

# Check Lambda function logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/step-functions-etl"

# Get log events
aws logs get-log-events \
    --log-group-name "/aws/lambda/step-functions-etl-dev-etl-extract" \
    --log-stream-name "2023/01/15/[$LATEST]stream-id"
```

### 2. Step Functions Monitoring
```bash
# Check state machine status
aws stepfunctions describe-state-machine \
    --state-machine-arn "arn:aws:states:region:account:stateMachine:step-functions-etl-dev-etl-state-machine"

# Check execution metrics
aws cloudwatch get-metric-statistics \
    --namespace "AWS/States" \
    --metric-name "ExecutionsStarted" \
    --dimensions Name=StateMachineArn,Value=arn:aws:states:region:account:stateMachine:step-functions-etl-dev-etl-state-machine \
    --start-time 2023-01-15T00:00:00Z \
    --end-time 2023-01-15T23:59:59Z \
    --period 300 \
    --statistics Sum
```

### 3. Glue Job Monitoring
```bash
# Check Glue job runs
aws glue get-job-runs --job-name "step-functions-etl-dev-etl-transform-job"

# Check Glue job metrics
aws cloudwatch get-metric-statistics \
    --namespace "AWS/Glue" \
    --metric-name "glue.driver.aggregate.numCompletedTasks" \
    --dimensions Name=JobName,Value=step-functions-etl-dev-etl-transform-job \
    --start-time 2023-01-15T00:00:00Z \
    --end-time 2023-01-15T23:59:59Z \
    --period 300 \
    --statistics Average
```

## Performance Optimization

### 1. Step Functions Optimization
```bash
# Use Express Workflows for high-volume, short-duration workflows
aws stepfunctions create-state-machine \
    --name "etl-express-workflow" \
    --type EXPRESS \
    --definition file://state-machine-definition.json \
    --role-arn "arn:aws:iam::account:role/StepFunctionsExecutionRole"
```

### 2. Lambda Optimization
```bash
# Optimize Lambda function settings
aws lambda update-function-configuration \
    --function-name "step-functions-etl-dev-etl-extract" \
    --memory-size 2048 \
    --timeout 300

# Enable provisioned concurrency for consistent performance
aws lambda put-provisioned-concurrency-config \
    --function-name "step-functions-etl-dev-etl-extract" \
    --provisioned-concurrency-config ProvisionedConcurrencyConfig={ProvisionedConcurrencyConfig={AllocatedConcurrency=10}}
```

### 3. Glue Job Optimization
```bash
# Optimize Glue job parameters
aws glue update-job \
    --job-name "step-functions-etl-dev-etl-transform-job" \
    --job-update '{
        "MaxCapacity": 4,
        "Timeout": 120,
        "GlueVersion": "4.0"
    }'
```

## Security Best Practices

### 1. IAM Security
```bash
# Create least-privilege IAM roles
aws iam create-role \
    --role-name "ETLStepFunctionsRole" \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "states.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }'
```

### 2. VPC Security
```bash
# Update security groups to restrict access
aws ec2 authorize-security-group-ingress \
    --group-id "sg-xxxxxxxxx" \
    --protocol tcp \
    --port 443 \
    --cidr "10.0.0.0/16"
```

### 3. Encryption
```bash
# Enable encryption for S3 buckets
aws s3api put-bucket-encryption \
    --bucket "step-functions-etl-dev-raw-data" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'
```

## Cost Optimization

### 1. Step Functions Cost Optimization
```bash
# Use Express Workflows for cost savings
aws stepfunctions create-state-machine \
    --name "etl-express-workflow" \
    --type EXPRESS \
    --definition file://state-machine-definition.json \
    --role-arn "arn:aws:iam::account:role/StepFunctionsExecutionRole"
```

### 2. Lambda Cost Optimization
```bash
# Right-size Lambda functions
aws lambda update-function-configuration \
    --function-name "step-functions-etl-dev-etl-extract" \
    --memory-size 512

# Use reserved capacity for cost savings
aws lambda put-reserved-concurrency-config \
    --function-name "step-functions-etl-dev-etl-extract" \
    --reserved-concurrency-config ReservedConcurrencyConfig={ReservedConcurrencyConfig={ReservedConcurrency=5}}
```

### 3. Glue Cost Optimization
```bash
# Use spot instances for cost savings
aws glue update-job \
    --job-name "step-functions-etl-dev-etl-transform-job" \
    --job-update '{
        "MaxCapacity": 2,
        "WorkerType": "G.1X",
        "NumberOfWorkers": 2
    }'
```

## Troubleshooting Common Issues

### 1. Step Functions Execution Failures
```bash
# Check execution history for errors
aws stepfunctions get-execution-history \
    --execution-arn "arn:aws:states:region:account:execution:step-functions-etl-dev-etl-state-machine:execution-id" \
    --query 'events[?type==`TaskFailed`]'

# Check Lambda function logs
aws logs get-log-events \
    --log-group-name "/aws/lambda/step-functions-etl-dev-etl-extract" \
    --log-stream-name "2023/01/15/[$LATEST]stream-id"
```

### 2. Lambda Function Issues
```bash
# Check Lambda function configuration
aws lambda get-function --function-name "step-functions-etl-dev-etl-extract"

# Check Lambda function logs
aws logs get-log-events \
    --log-group-name "/aws/lambda/step-functions-etl-dev-etl-extract" \
    --log-stream-name "2023/01/15/[$LATEST]stream-id"
```

### 3. Glue Job Issues
```bash
# Check Glue job runs
aws glue get-job-runs --job-name "step-functions-etl-dev-etl-transform-job"

# Check Glue job logs
aws logs get-log-events \
    --log-group-name "/aws-glue/jobs/logs-v2" \
    --log-stream-name "step-functions-etl-dev-etl-transform-job"
```

## Cleanup

### 1. Stop Step Functions Executions
```bash
# List running executions
aws stepfunctions list-executions \
    --state-machine-arn "arn:aws:states:region:account:stateMachine:step-functions-etl-dev-etl-state-machine" \
    --status-filter RUNNING

# Stop executions
aws stepfunctions stop-execution \
    --execution-arn "arn:aws:states:region:account:execution:step-functions-etl-dev-etl-state-machine:execution-id"
```

### 2. Destroy Terraform Infrastructure
```bash
cd terraform
terraform destroy -var-file="../terraform.tfvars"
```

### 3. Clean Up S3 Buckets
```bash
# Delete S3 bucket contents
aws s3 rm s3://step-functions-etl-dev-raw-data --recursive
aws s3 rm s3://step-functions-etl-dev-processed-data --recursive
aws s3 rm s3://step-functions-etl-dev-aggregated-data --recursive
aws s3 rm s3://step-functions-etl-dev-logs --recursive
```

## Next Steps

1. **Data Pipeline Setup**: Configure data sources and destinations
2. **Job Scheduling**: Set up EventBridge rules for orchestration
3. **Monitoring**: Configure alerts and dashboards
4. **Cost Optimization**: Implement right-sizing and reserved capacity
5. **Security**: Review and enhance security configurations
6. **Performance**: Optimize Step Functions and Lambda functions
7. **Disaster Recovery**: Set up backup and recovery procedures

## Support and Resources

- **AWS Step Functions Documentation**: https://docs.aws.amazon.com/step-functions/
- **AWS Lambda Documentation**: https://docs.aws.amazon.com/lambda/
- **AWS Glue Documentation**: https://docs.aws.amazon.com/glue/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest

For additional help, refer to the troubleshooting guide and performance optimization documentation.

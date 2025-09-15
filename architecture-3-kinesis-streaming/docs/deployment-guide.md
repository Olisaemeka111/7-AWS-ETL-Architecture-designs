# Architecture 3: Kinesis Streaming ETL - Deployment Guide

## Prerequisites

### AWS Account Setup
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Python 3.9+ for Lambda functions
- Access to AWS services: Kinesis, Lambda, S3, Redshift, OpenSearch, SNS, CloudWatch

### Required IAM Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "kinesis:*",
                "lambda:*",
                "s3:*",
                "redshift:*",
                "es:*",
                "sns:*",
                "cloudwatch:*",
                "logs:*",
                "vpc:*",
                "iam:*",
                "dynamodb:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## Deployment Steps

### 1. Clone and Setup
```bash
cd architecture-3-kinesis-streaming
```

### 2. Configure Variables
Edit `terraform/variables.tf` with your specific values:
```hcl
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "kinesis-streaming-etl"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
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
# Package and deploy stream processor
cd ../src/lambda
zip -r stream_processor.zip stream_processor.py
aws lambda update-function-code \
  --function-name kinesis-streaming-etl-dev-stream-processor \
  --zip-file fileb://stream_processor.zip

# Package and deploy data enricher
zip -r data_enricher.zip data_enricher.py
aws lambda update-function-code \
  --function-name kinesis-streaming-etl-dev-data-enricher \
  --zip-file fileb://data_enricher.zip

# Package and deploy anomaly detector
zip -r anomaly_detector.zip anomaly_detector.py
aws lambda update-function-code \
  --function-name kinesis-streaming-etl-dev-anomaly-detector \
  --zip-file fileb://anomaly_detector.zip
```

## Configuration

### Kinesis Stream Configuration
```bash
# Configure Kinesis streams
aws kinesis describe-stream \
  --stream-name kinesis-streaming-etl-dev-main-stream

# Update shard count if needed
aws kinesis update-shard-count \
  --stream-name kinesis-streaming-etl-dev-main-stream \
  --target-shard-count 4 \
  --scaling-type UNIFORM_SCALING
```

### Kinesis Analytics Configuration
```bash
# Start Kinesis Analytics application
aws kinesisanalytics start-application \
  --application-name kinesis-streaming-etl-dev-stream-processor

# Check application status
aws kinesisanalytics describe-application \
  --application-name kinesis-streaming-etl-dev-stream-processor
```

### Lambda Event Source Mapping
```bash
# Create event source mapping for stream processor
aws lambda create-event-source-mapping \
  --function-name kinesis-streaming-etl-dev-stream-processor \
  --event-source-arn arn:aws:kinesis:us-east-1:123456789012:stream/kinesis-streaming-etl-dev-main-stream \
  --starting-position LATEST \
  --batch-size 100

# Create event source mapping for data enricher
aws lambda create-event-source-mapping \
  --function-name kinesis-streaming-etl-dev-data-enricher \
  --event-source-arn arn:aws:kinesis:us-east-1:123456789012:stream/kinesis-streaming-etl-dev-analytics-stream \
  --starting-position LATEST \
  --batch-size 50
```

## Testing

### 1. Test Kinesis Streams
```bash
# Send test data to main stream
aws kinesis put-record \
  --stream-name kinesis-streaming-etl-dev-main-stream \
  --partition-key "test-partition" \
  --data '{"user_id":"test-user","event_type":"test-event","timestamp":"2024-01-01T00:00:00Z","value":100}'
```

### 2. Test Lambda Functions
```bash
# Test stream processor function
aws lambda invoke \
  --function-name kinesis-streaming-etl-dev-stream-processor \
  --payload '{"test": true}' \
  response.json

# Test data enricher function
aws lambda invoke \
  --function-name kinesis-streaming-etl-dev-data-enricher \
  --payload '{"test": true}' \
  response.json
```

### 3. Test End-to-End Pipeline
```bash
# Send multiple test records
for i in {1..10}; do
  aws kinesis put-record \
    --stream-name kinesis-streaming-etl-dev-main-stream \
    --partition-key "test-partition-$i" \
    --data "{\"user_id\":\"user-$i\",\"event_type\":\"test-event\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"value\":$((RANDOM % 1000))}"
done
```

## Monitoring Setup

### 1. CloudWatch Dashboard
```bash
# Create dashboard
aws cloudwatch put-dashboard \
  --dashboard-name "Kinesis-Streaming-ETL-Monitoring" \
  --dashboard-body file://monitoring/cloudwatch-dashboard.json
```

### 2. CloudWatch Alarms
```bash
# Create Kinesis stream throttling alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "Kinesis-Stream-Throttling" \
  --alarm-description "Kinesis stream throttling detected" \
  --metric-name WriteProvisionedThroughputExceeded \
  --namespace AWS/Kinesis \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=StreamName,Value=kinesis-streaming-etl-dev-main-stream

# Create Lambda error rate alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "Lambda-Error-Rate" \
  --alarm-description "Lambda error rate too high" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=FunctionName,Value=kinesis-streaming-etl-dev-stream-processor
```

## Troubleshooting

### Common Issues

#### 1. Kinesis Stream Throttling
**Symptoms:**
- WriteProvisionedThroughputExceeded errors
- High latency in data processing
- Backlog in stream processing

**Solutions:**
```bash
# Check stream metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Kinesis \
  --metric-name IncomingRecords \
  --dimensions Name=StreamName,Value=kinesis-streaming-etl-dev-main-stream \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 300 \
  --statistics Average

# Scale up shards
aws kinesis update-shard-count \
  --stream-name kinesis-streaming-etl-dev-main-stream \
  --target-shard-count 8 \
  --scaling-type UNIFORM_SCALING
```

#### 2. Lambda Function Errors
**Symptoms:**
- Lambda function failures
- High error rates
- Processing delays

**Solutions:**
```bash
# Check Lambda logs
aws logs get-log-events \
  --log-group-name "/aws/lambda/kinesis-streaming-etl-dev-stream-processor" \
  --log-stream-name "latest"

# Check function configuration
aws lambda get-function-configuration \
  --function-name kinesis-streaming-etl-dev-stream-processor

# Increase memory or timeout if needed
aws lambda update-function-configuration \
  --function-name kinesis-streaming-etl-dev-stream-processor \
  --memory-size 1024 \
  --timeout 120
```

#### 3. Kinesis Analytics Issues
**Symptoms:**
- Analytics application not processing data
- SQL errors in analytics
- Checkpoint failures

**Solutions:**
```bash
# Check application status
aws kinesisanalytics describe-application \
  --application-name kinesis-streaming-etl-dev-stream-processor

# Check application logs
aws logs get-log-events \
  --log-group-name "/aws/kinesisanalytics/kinesis-streaming-etl-dev-stream-processor" \
  --log-stream-name "latest"

# Restart application if needed
aws kinesisanalytics stop-application \
  --application-name kinesis-streaming-etl-dev-stream-processor

aws kinesisanalytics start-application \
  --application-name kinesis-streaming-etl-dev-stream-processor
```

### Debugging Steps

1. **Check Kinesis Stream Health**
   ```bash
   # Get stream description
   aws kinesis describe-stream \
     --stream-name kinesis-streaming-etl-dev-main-stream
   
   # Check stream metrics
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Kinesis \
     --metric-name IncomingRecords \
     --dimensions Name=StreamName,Value=kinesis-streaming-etl-dev-main-stream \
     --start-time 2024-01-01T00:00:00Z \
     --end-time 2024-01-01T23:59:59Z \
     --period 300 \
     --statistics Average
   ```

2. **Monitor Lambda Performance**
   ```bash
   # Get function metrics
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Lambda \
     --metric-name Duration \
     --dimensions Name=FunctionName,Value=kinesis-streaming-etl-dev-stream-processor \
     --start-time 2024-01-01T00:00:00Z \
     --end-time 2024-01-01T23:59:59Z \
     --period 300 \
     --statistics Average
   ```

3. **Check Data Flow**
   ```bash
   # Check S3 data
   aws s3 ls s3://kinesis-streaming-etl-dev-raw-data/ --recursive
   
   # Check Firehose delivery
   aws firehose describe-delivery-stream \
     --delivery-stream-name kinesis-streaming-etl-dev-s3-delivery
   ```

## Performance Optimization

### 1. Kinesis Stream Optimization
```python
# Optimize shard count based on throughput
def calculate_optimal_shards(records_per_second, bytes_per_record):
    """
    Calculate optimal shard count for Kinesis stream
    """
    # Kinesis limits: 1000 records/second and 1MB/second per shard
    records_per_shard = 1000
    bytes_per_shard = 1024 * 1024  # 1MB
    
    shards_for_records = math.ceil(records_per_second / records_per_shard)
    shards_for_bytes = math.ceil((records_per_second * bytes_per_record) / bytes_per_shard)
    
    return max(shards_for_records, shards_for_bytes)
```

### 2. Lambda Optimization
```python
# Optimize Lambda batch size
def optimize_batch_size(record_size, processing_time):
    """
    Optimize Lambda batch size for Kinesis processing
    """
    # Consider Lambda timeout and memory
    max_batch_size = 10000  # Kinesis limit
    optimal_batch_size = min(max_batch_size, 1000)  # Start with 1000
    
    # Adjust based on processing time
    if processing_time > 5:  # seconds
        optimal_batch_size = min(optimal_batch_size, 100)
    
    return optimal_batch_size
```

### 3. Data Compression
```python
# Compress data before sending to Kinesis
import gzip
import json

def compress_data(data):
    """
    Compress data for efficient streaming
    """
    json_data = json.dumps(data).encode('utf-8')
    compressed_data = gzip.compress(json_data)
    return compressed_data
```

## Security Configuration

### 1. IAM Roles and Policies
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "kinesis:PutRecord",
                "kinesis:PutRecords"
            ],
            "Resource": "arn:aws:kinesis:region:account:stream/stream-name"
        },
        {
            "Effect": "Allow",
            "Action": [
                "kinesis:GetRecords",
                "kinesis:GetShardIterator",
                "kinesis:DescribeStream"
            ],
            "Resource": "arn:aws:kinesis:region:account:stream/stream-name"
        }
    ]
}
```

### 2. VPC Configuration
- Deploy Lambda functions in VPC for database access
- Use VPC endpoints for S3 access
- Configure security groups for network isolation
- Enable VPC flow logs for monitoring

### 3. Encryption
```bash
# Enable encryption for Kinesis streams
aws kinesis create-stream \
  --stream-name encrypted-stream \
  --shard-count 2 \
  --encryption-type KMS \
  --kms-key-id alias/aws/kinesis
```

## Maintenance

### 1. Regular Tasks
- Monitor stream throughput and scale as needed
- Review and optimize Lambda function performance
- Check data quality and processing accuracy
- Update enrichment data sources

### 2. Backup Strategy
- Regular S3 bucket backups
- Kinesis stream checkpoint backups
- Lambda function code backups
- Configuration backups

### 3. Scaling Considerations
- Monitor data volume growth
- Adjust shard count based on throughput
- Scale Lambda functions based on load
- Optimize data retention periods

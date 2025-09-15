# Architecture 1: Serverless ETL with Lambda - Troubleshooting Guide

## Common Issues and Solutions

### 1. Lambda Function Issues

#### Issue: Lambda Timeout
**Symptoms:**
- Function execution times out
- CloudWatch logs show "Task timed out after X seconds"
- SQS messages remain in queue

**Causes:**
- Large data processing operations
- Network latency to external services
- Inefficient code logic
- Insufficient memory allocation

**Solutions:**
```python
# Increase timeout in Lambda configuration
import json
import boto3

def lambda_handler(event, context):
    # Implement timeout handling
    try:
        # Your processing logic here
        result = process_data()
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
    except Exception as e:
        # Log error and return gracefully
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

**Prevention:**
- Set appropriate timeout values (max 15 minutes)
- Implement chunking for large datasets
- Use async processing where possible
- Monitor execution times in CloudWatch

#### Issue: Memory Errors
**Symptoms:**
- "Process exited before completing request"
- OutOfMemoryError in logs
- Function crashes during execution

**Solutions:**
```bash
# Increase memory allocation
aws lambda update-function-configuration \
  --function-name etl-extract \
  --memory-size 1024
```

**Memory Optimization:**
```python
# Optimize memory usage
import gc
import pandas as pd

def process_large_dataset():
    # Process data in chunks
    chunk_size = 1000
    for chunk in pd.read_csv('large_file.csv', chunksize=chunk_size):
        process_chunk(chunk)
        # Force garbage collection
        gc.collect()
```

#### Issue: Cold Start Delays
**Symptoms:**
- First invocation takes longer
- Inconsistent performance
- User experience degradation

**Solutions:**
```python
# Implement connection pooling
import boto3
import pymysql
from functools import lru_cache

# Cache database connections
@lru_cache(maxsize=1)
def get_db_connection():
    return pymysql.connect(
        host='your-rds-endpoint',
        user='username',
        password='password',
        database='database'
    )

# Use provisioned concurrency for critical functions
aws lambda put-provisioned-concurrency-config \
  --function-name etl-extract \
  --provisioned-concurrency-config ProvisionedConcurrencyConfig='{ProvisionedConcurrencyCount=2}'
```

### 2. SQS Issues

#### Issue: Messages Stuck in Queue
**Symptoms:**
- Messages remain in SQS queue
- No Lambda invocations triggered
- Queue depth increasing

**Causes:**
- Lambda function errors
- Incorrect visibility timeout
- Dead letter queue configuration issues

**Solutions:**
```bash
# Check queue attributes
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/etl-queue \
  --attribute-names All

# Adjust visibility timeout
aws sqs set-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/etl-queue \
  --attributes VisibilityTimeoutSeconds=300
```

**Debugging Steps:**
```python
# Add comprehensive logging
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Process message
        for record in event['Records']:
            logger.info(f"Processing record: {record}")
            # Your processing logic here
            
    except Exception as e:
        logger.error(f"Error processing message: {str(e)}")
        # Re-raise to trigger DLQ
        raise
```

#### Issue: Duplicate Messages
**Symptoms:**
- Same data processed multiple times
- Inconsistent results
- Data quality issues

**Solutions:**
```python
# Implement idempotency
import hashlib
import json

def lambda_handler(event, context):
    processed_messages = set()
    
    for record in event['Records']:
        # Create message hash for deduplication
        message_hash = hashlib.md5(
            record['body'].encode()
        ).hexdigest()
        
        if message_hash in processed_messages:
            logger.info(f"Duplicate message detected: {message_hash}")
            continue
            
        processed_messages.add(message_hash)
        # Process message
        process_message(record)
```

### 3. S3 Issues

#### Issue: Access Denied Errors
**Symptoms:**
- "Access Denied" errors in Lambda logs
- Files not accessible from Lambda
- Upload/download failures

**Solutions:**
```json
// S3 Bucket Policy
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowLambdaAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::123456789012:role/etl-lambda-role"
            },
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::etl-staging-bucket/*"
        }
    ]
}
```

#### Issue: Large File Processing
**Symptoms:**
- Lambda timeout on large files
- Memory issues with large datasets
- Inefficient processing

**Solutions:**
```python
# Process large files in chunks
import boto3
import pandas as pd
from io import BytesIO

def process_large_s3_file(bucket, key):
    s3 = boto3.client('s3')
    
    # Get file size first
    response = s3.head_object(Bucket=bucket, Key=key)
    file_size = response['ContentLength']
    
    if file_size > 100 * 1024 * 1024:  # 100MB
        # Process in chunks
        chunk_size = 10 * 1024 * 1024  # 10MB chunks
        for i in range(0, file_size, chunk_size):
            end = min(i + chunk_size, file_size)
            chunk = s3.get_object(
                Bucket=bucket,
                Key=key,
                Range=f'bytes={i}-{end-1}'
            )
            process_chunk(chunk['Body'].read())
    else:
        # Process entire file
        obj = s3.get_object(Bucket=bucket, Key=key)
        process_file(obj['Body'].read())
```

### 4. Redshift Issues

#### Issue: Connection Timeouts
**Symptoms:**
- Lambda cannot connect to Redshift
- Connection timeout errors
- Network connectivity issues

**Solutions:**
```python
# Implement connection retry logic
import psycopg2
import time
from psycopg2 import pool

class RedshiftConnectionPool:
    def __init__(self):
        self.connection_pool = None
        
    def create_pool(self):
        try:
            self.connection_pool = psycopg2.pool.ThreadedConnectionPool(
                1, 20,
                host='your-redshift-cluster.amazonaws.com',
                port=5439,
                database='etl_warehouse',
                user='username',
                password='password'
            )
        except Exception as e:
            print(f"Error creating connection pool: {e}")
            
    def get_connection(self):
        max_retries = 3
        for attempt in range(max_retries):
            try:
                return self.connection_pool.getconn()
            except Exception as e:
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)  # Exponential backoff
                else:
                    raise e
```

#### Issue: Query Performance
**Symptoms:**
- Slow query execution
- Lambda timeouts during data loading
- High Redshift costs

**Solutions:**
```sql
-- Optimize table design
CREATE TABLE sales_data (
    id INTEGER,
    date DATE,
    amount DECIMAL(10,2),
    region VARCHAR(50)
)
DISTKEY(region)  -- Distribute by region
SORTKEY(date);   -- Sort by date for time-series queries

-- Use COPY command for bulk loading
COPY sales_data 
FROM 's3://etl-staging-bucket/data/sales_data.parquet'
IAM_ROLE 'arn:aws:iam::123456789012:role/RedshiftRole'
FORMAT AS PARQUET;
```

### 5. EventBridge Issues

#### Issue: Rules Not Triggering
**Symptoms:**
- Scheduled events not firing
- Lambda functions not invoked
- Missing execution logs

**Solutions:**
```bash
# Check EventBridge rules
aws events list-rules --name-prefix "etl-"

# Verify rule targets
aws events list-targets-by-rule --rule "etl-daily-extract"

# Test rule manually
aws events put-events \
  --entries '[
    {
      "Source": "etl.test",
      "DetailType": "Test Event",
      "Detail": "{\"test\": true}"
    }
  ]'
```

#### Issue: Cross-Account Events
**Symptoms:**
- Events not received from other accounts
- Permission denied errors
- Missing cross-account data

**Solutions:**
```json
// EventBridge resource policy
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCrossAccountEvents",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::987654321098:root"
            },
            "Action": "events:PutEvents",
            "Resource": "arn:aws:events:us-east-1:123456789012:event-bus/default"
        }
    ]
}
```

## Monitoring and Alerting

### CloudWatch Alarms
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
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=FunctionName,Value=etl-extract

# SQS queue depth alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "ETL-SQS-QueueDepth" \
  --alarm-description "ETL SQS queue too deep" \
  --metric-name ApproximateNumberOfVisibleMessages \
  --namespace AWS/SQS \
  --statistic Average \
  --period 300 \
  --threshold 100 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=QueueName,Value=etl-queue
```

### Custom Metrics
```python
# Send custom metrics to CloudWatch
import boto3

def send_custom_metric(metric_name, value, unit='Count'):
    cloudwatch = boto3.client('cloudwatch')
    
    cloudwatch.put_metric_data(
        Namespace='ETL/Pipeline',
        MetricData=[
            {
                'MetricName': metric_name,
                'Value': value,
                'Unit': unit,
                'Dimensions': [
                    {
                        'Name': 'Environment',
                        'Value': 'Production'
                    }
                ]
            }
        ]
    )
```

## Debugging Tools and Commands

### 1. CloudWatch Logs Analysis
```bash
# Search for errors in logs
aws logs filter-log-events \
  --log-group-name "/aws/lambda/etl-extract" \
  --filter-pattern "ERROR"

# Get recent log events
aws logs get-log-events \
  --log-group-name "/aws/lambda/etl-extract" \
  --log-stream-name "2024/01/01/[$LATEST]abc123" \
  --start-time 1640995200000
```

### 2. Lambda Function Testing
```bash
# Test function with sample payload
aws lambda invoke \
  --function-name etl-extract \
  --payload '{"test": true, "source": "manual"}' \
  --log-type Tail \
  response.json

# Get function configuration
aws lambda get-function-configuration \
  --function-name etl-extract
```

### 3. SQS Queue Inspection
```bash
# Get queue attributes
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/etl-queue \
  --attribute-names All

# Purge queue (use with caution)
aws sqs purge-queue \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/etl-queue
```

### 4. Redshift Query Analysis
```sql
-- Check running queries
SELECT 
    query,
    starttime,
    duration,
    user_name,
    query_text
FROM stl_query 
WHERE starttime > current_date 
ORDER BY starttime DESC;

-- Check query performance
SELECT 
    query,
    AVG(duration) as avg_duration,
    COUNT(*) as execution_count
FROM stl_query 
WHERE starttime > current_date - 7
GROUP BY query
ORDER BY avg_duration DESC;
```

## Performance Optimization

### 1. Lambda Performance
```python
# Optimize imports
import json
import boto3
# Import only what you need

# Use connection pooling
s3_client = boto3.client('s3')
redshift_connection = None

def get_redshift_connection():
    global redshift_connection
    if redshift_connection is None:
        redshift_connection = psycopg2.connect(...)
    return redshift_connection
```

### 2. Data Processing Optimization
```python
# Use pandas efficiently
import pandas as pd
import numpy as np

def process_data_efficiently(data):
    # Use vectorized operations
    df = pd.DataFrame(data)
    
    # Avoid loops, use vectorized operations
    df['processed_column'] = df['column1'] * df['column2']
    
    # Use appropriate data types
    df['date_column'] = pd.to_datetime(df['date_column'])
    df['numeric_column'] = pd.to_numeric(df['numeric_column'])
    
    return df
```

### 3. Memory Management
```python
# Implement memory-efficient processing
import gc
import psutil

def monitor_memory():
    memory_percent = psutil.virtual_memory().percent
    if memory_percent > 80:
        gc.collect()
        print(f"Memory usage: {memory_percent}%")

def process_large_dataset():
    # Process in batches
    batch_size = 1000
    for i in range(0, len(data), batch_size):
        batch = data[i:i+batch_size]
        process_batch(batch)
        monitor_memory()
```

## Emergency Procedures

### 1. Pipeline Failure Recovery
```bash
# Stop all EventBridge rules
aws events disable-rule --name "etl-daily-extract"

# Check and clear SQS queues
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/etl-queue \
  --attribute-names ApproximateNumberOfVisibleMessages

# Purge queue if necessary
aws sqs purge-queue \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/etl-queue
```

### 2. Data Recovery
```bash
# Restore from S3 backup
aws s3 cp s3://etl-backup-bucket/backup-2024-01-01/ s3://etl-staging-bucket/ --recursive

# Restore Redshift from snapshot
aws redshift restore-from-cluster-snapshot \
  --cluster-identifier etl-warehouse-restored \
  --snapshot-identifier etl-warehouse-snapshot-2024-01-01
```

### 3. Rollback Procedures
```bash
# Deploy previous Lambda version
aws lambda update-function-code \
  --function-name etl-extract \
  --zip-file fileb://extract-previous.zip

# Revert Terraform state
terraform plan -var-file="terraform.tfvars.backup"
terraform apply -var-file="terraform.tfvars.backup"
```

## Best Practices for Prevention

### 1. Error Handling
```python
# Implement comprehensive error handling
def lambda_handler(event, context):
    try:
        # Main processing logic
        result = process_data(event)
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
    except ValidationError as e:
        # Handle validation errors
        logger.error(f"Validation error: {e}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid input data'})
        }
    except DatabaseError as e:
        # Handle database errors
        logger.error(f"Database error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Database connection failed'})
        }
    except Exception as e:
        # Handle unexpected errors
        logger.error(f"Unexpected error: {e}")
        raise  # Re-raise to trigger DLQ
```

### 2. Monitoring and Logging
```python
# Implement structured logging
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def log_processing_step(step, data_size, duration):
    logger.info(json.dumps({
        'step': step,
        'data_size': data_size,
        'duration_ms': duration,
        'timestamp': time.time()
    }))
```

### 3. Testing and Validation
```python
# Implement data validation
def validate_data(data):
    required_fields = ['id', 'date', 'amount']
    
    for field in required_fields:
        if field not in data:
            raise ValidationError(f"Missing required field: {field}")
    
    # Validate data types
    if not isinstance(data['amount'], (int, float)):
        raise ValidationError("Amount must be numeric")
    
    return True
```

This troubleshooting guide provides comprehensive solutions for common issues in the serverless ETL architecture. Regular monitoring, proper error handling, and following best practices will help prevent most issues and ensure smooth operation of your ETL pipeline.

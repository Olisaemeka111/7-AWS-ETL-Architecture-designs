# Architecture 1: Serverless ETL with Lambda - Performance Optimization

## Overview
This document provides comprehensive performance optimization strategies for the serverless ETL architecture using AWS Lambda, SQS, S3, and Redshift.

## Lambda Performance Optimization

### 1. Memory and CPU Optimization

#### Right-sizing Memory Allocation
```python
# Optimize memory based on workload
def calculate_optimal_memory(data_size_mb, processing_complexity):
    """
    Calculate optimal Lambda memory allocation
    """
    base_memory = 128  # MB
    
    # Memory for data processing
    data_memory = data_size_mb * 2  # 2x data size for processing
    
    # Memory for processing complexity
    complexity_multiplier = {
        'simple': 1.0,
        'medium': 1.5,
        'complex': 2.0
    }
    
    optimal_memory = (base_memory + data_memory) * complexity_multiplier.get(processing_complexity, 1.0)
    
    # Round to nearest Lambda memory tier
    memory_tiers = [128, 256, 512, 1024, 1536, 2048, 3008]
    return min(memory_tiers, key=lambda x: abs(x - optimal_memory))
```

#### CPU Optimization
```python
# Lambda automatically allocates CPU proportional to memory
# Memory allocation directly affects CPU power
memory_cpu_mapping = {
    128: 0.1,    # vCPU
    256: 0.2,
    512: 0.4,
    1024: 0.8,
    2048: 1.6,
    3008: 2.4
}
```

### 2. Cold Start Optimization

#### Connection Pooling
```python
import boto3
import pymysql
from functools import lru_cache

# Global connection pool
connection_pool = {}

@lru_cache(maxsize=1)
def get_rds_connection():
    """Cache database connection"""
    if 'rds_connection' not in connection_pool:
        connection_pool['rds_connection'] = pymysql.connect(
            host=os.environ['RDS_ENDPOINT'],
            user=os.environ['RDS_USERNAME'],
            password=os.environ['RDS_PASSWORD'],
            database=os.environ['RDS_DATABASE'],
            autocommit=True
        )
    return connection_pool['rds_connection']

@lru_cache(maxsize=1)
def get_s3_client():
    """Cache S3 client"""
    return boto3.client('s3')

@lru_cache(maxsize=1)
def get_sqs_client():
    """Cache SQS client"""
    return boto3.client('sqs')
```

#### Provisioned Concurrency
```bash
# Enable provisioned concurrency for critical functions
aws lambda put-provisioned-concurrency-config \
  --function-name etl-extract \
  --provisioned-concurrency-config ProvisionedConcurrencyConfig='{ProvisionedConcurrencyCount=2}'
```

### 3. Code Optimization

#### Efficient Data Processing
```python
import pandas as pd
import numpy as np
from concurrent.futures import ThreadPoolExecutor
import multiprocessing

def process_data_efficiently(data_chunks):
    """
    Process data chunks in parallel
    """
    with ThreadPoolExecutor(max_workers=4) as executor:
        results = list(executor.map(process_chunk, data_chunks))
    return results

def process_chunk(chunk):
    """
    Process individual data chunk
    """
    # Use vectorized operations
    df = pd.DataFrame(chunk)
    
    # Avoid loops, use vectorized operations
    df['processed_column'] = df['column1'] * df['column2']
    
    # Use appropriate data types
    df['date_column'] = pd.to_datetime(df['date_column'])
    df['numeric_column'] = pd.to_numeric(df['numeric_column'])
    
    return df.to_dict('records')
```

#### Memory Management
```python
import gc
import psutil

def monitor_memory():
    """Monitor memory usage"""
    memory_percent = psutil.virtual_memory().percent
    if memory_percent > 80:
        gc.collect()
        logger.warning(f"Memory usage: {memory_percent}%")

def process_large_dataset(data):
    """Process large datasets efficiently"""
    chunk_size = 1000
    results = []
    
    for i in range(0, len(data), chunk_size):
        chunk = data[i:i+chunk_size]
        processed_chunk = process_chunk(chunk)
        results.extend(processed_chunk)
        
        # Monitor memory and cleanup
        monitor_memory()
        if i % 10000 == 0:
            gc.collect()
    
    return results
```

## SQS Performance Optimization

### 1. Message Batching
```python
import boto3
import json
from typing import List, Dict

def send_messages_batch(sqs_client, queue_url: str, messages: List[Dict]):
    """
    Send messages in batches for better performance
    """
    batch_size = 10  # SQS batch limit
    results = []
    
    for i in range(0, len(messages), batch_size):
        batch = messages[i:i+batch_size]
        
        entries = []
        for j, message in enumerate(batch):
            entries.append({
                'Id': str(i + j),
                'MessageBody': json.dumps(message)
            })
        
        response = sqs_client.send_message_batch(
            QueueUrl=queue_url,
            Entries=entries
        )
        
        results.extend(response.get('Successful', []))
        
        # Handle failed messages
        if response.get('Failed'):
            logger.warning(f"Failed to send {len(response['Failed'])} messages")
    
    return results
```

### 2. Visibility Timeout Optimization
```python
def calculate_visibility_timeout(lambda_timeout: int, processing_time: int) -> int:
    """
    Calculate optimal visibility timeout
    """
    # Add buffer time for processing
    buffer_time = 60  # seconds
    optimal_timeout = max(lambda_timeout, processing_time) + buffer_time
    
    # SQS visibility timeout limits
    return min(optimal_timeout, 43200)  # Max 12 hours
```

### 3. Dead Letter Queue Configuration
```python
# Configure DLQ with appropriate settings
dlq_config = {
    'maxReceiveCount': 3,
    'visibilityTimeoutSeconds': 300,
    'messageRetentionPeriod': 1209600  # 14 days
}
```

## S3 Performance Optimization

### 1. Multipart Uploads
```python
import boto3
from boto3.s3.transfer import TransferConfig

def upload_large_file_s3(s3_client, bucket: str, key: str, file_path: str):
    """
    Upload large files using multipart upload
    """
    config = TransferConfig(
        multipart_threshold=1024 * 25,  # 25MB
        max_concurrency=10,
        multipart_chunksize=1024 * 25,
        use_threads=True
    )
    
    s3_client.upload_file(
        file_path, bucket, key,
        Config=config
    )
```

### 2. Data Compression
```python
import gzip
import json

def compress_data(data: List[Dict]) -> bytes:
    """
    Compress data before uploading to S3
    """
    json_data = json.dumps(data).encode('utf-8')
    compressed_data = gzip.compress(json_data)
    return compressed_data

def upload_compressed_data(s3_client, bucket: str, key: str, data: List[Dict]):
    """
    Upload compressed data to S3
    """
    compressed_data = compress_data(data)
    
    s3_client.put_object(
        Bucket=bucket,
        Key=key,
        Body=compressed_data,
        ContentType='application/gzip',
        ContentEncoding='gzip'
    )
```

### 3. Storage Class Optimization
```python
def optimize_storage_class(file_access_pattern: str, file_size: int) -> str:
    """
    Choose optimal S3 storage class
    """
    if file_access_pattern == 'frequent':
        return 'STANDARD'
    elif file_access_pattern == 'infrequent' and file_size > 128 * 1024:  # 128KB
        return 'STANDARD_IA'
    elif file_access_pattern == 'archive':
        return 'GLACIER'
    else:
        return 'STANDARD'
```

## Redshift Performance Optimization

### 1. Connection Pooling
```python
import psycopg2
from psycopg2 import pool
import threading

class RedshiftConnectionPool:
    def __init__(self, connection_params: Dict, min_connections: int = 1, max_connections: int = 10):
        self.connection_pool = psycopg2.pool.ThreadedConnectionPool(
            min_connections, max_connections, **connection_params
        )
        self.lock = threading.Lock()
    
    def get_connection(self):
        with self.lock:
            return self.connection_pool.getconn()
    
    def return_connection(self, connection):
        with self.lock:
            self.connection_pool.putconn(connection)
    
    def close_all_connections(self):
        self.connection_pool.closeall()
```

### 2. Bulk Loading Optimization
```python
def bulk_load_to_redshift(connection, table_name: str, data: List[Dict]):
    """
    Optimize bulk loading to Redshift
    """
    # Use COPY command for bulk loading
    copy_sql = f"""
    COPY {table_name}
    FROM 's3://your-bucket/data/{table_name}.csv'
    IAM_ROLE 'arn:aws:iam::123456789012:role/RedshiftRole'
    CSV
    IGNOREHEADER 1
    COMPUPDATE OFF
    STATUPDATE OFF
    """
    
    with connection.cursor() as cursor:
        cursor.execute(copy_sql)
        connection.commit()
```

### 3. Query Optimization
```python
def optimize_redshift_queries():
    """
    Redshift query optimization best practices
    """
    optimization_tips = {
        'distribution_key': 'Choose high-cardinality columns',
        'sort_key': 'Use columns frequently used in WHERE clauses',
        'compression': 'Enable compression for large tables',
        'vacuum': 'Run VACUUM regularly to reclaim space',
        'analyze': 'Run ANALYZE to update table statistics'
    }
    return optimization_tips
```

## End-to-End Pipeline Optimization

### 1. Parallel Processing
```python
import asyncio
import aiohttp
from concurrent.futures import ThreadPoolExecutor

async def parallel_data_extraction(sources: List[str]):
    """
    Extract data from multiple sources in parallel
    """
    async with aiohttp.ClientSession() as session:
        tasks = [extract_from_source(session, source) for source in sources]
        results = await asyncio.gather(*tasks)
    return results

async def extract_from_source(session, source: str):
    """
    Extract data from a single source
    """
    async with session.get(source) as response:
        return await response.json()
```

### 2. Incremental Processing
```python
def implement_incremental_processing(last_processed_timestamp: str):
    """
    Process only new or changed data
    """
    # Query for data modified since last run
    query = f"""
    SELECT * FROM source_table 
    WHERE modified_date > '{last_processed_timestamp}'
    ORDER BY modified_date
    """
    
    return execute_query(query)
```

### 3. Error Handling and Retry Logic
```python
import time
from functools import wraps

def retry_with_exponential_backoff(max_retries: int = 3, base_delay: float = 1.0):
    """
    Decorator for retry logic with exponential backoff
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    if attempt == max_retries - 1:
                        raise e
                    
                    delay = base_delay * (2 ** attempt)
                    logger.warning(f"Attempt {attempt + 1} failed: {e}. Retrying in {delay}s")
                    time.sleep(delay)
            
            return None
        return wrapper
    return decorator

@retry_with_exponential_backoff(max_retries=3)
def process_data_with_retry(data):
    """
    Process data with automatic retry
    """
    # Your data processing logic here
    return process_data(data)
```

## Monitoring and Metrics

### 1. Custom Metrics
```python
import boto3

def send_custom_metrics(metrics: Dict[str, float]):
    """
    Send custom metrics to CloudWatch
    """
    cloudwatch = boto3.client('cloudwatch')
    
    metric_data = []
    for metric_name, value in metrics.items():
        metric_data.append({
            'MetricName': metric_name,
            'Value': value,
            'Unit': 'Count',
            'Dimensions': [
                {
                    'Name': 'Environment',
                    'Value': os.environ.get('ENVIRONMENT', 'dev')
                }
            ]
        })
    
    cloudwatch.put_metric_data(
        Namespace='ETL/Pipeline',
        MetricData=metric_data
    )
```

### 2. Performance Monitoring
```python
import time
from contextlib import contextmanager

@contextmanager
def measure_performance(operation_name: str):
    """
    Context manager to measure operation performance
    """
    start_time = time.time()
    try:
        yield
    finally:
        duration = time.time() - start_time
        logger.info(f"{operation_name} took {duration:.2f} seconds")
        
        # Send metric to CloudWatch
        send_custom_metrics({f"{operation_name}_duration": duration})
```

## Cost Optimization

### 1. Resource Right-sizing
```python
def optimize_lambda_costs():
    """
    Optimize Lambda costs through right-sizing
    """
    optimization_strategies = {
        'memory_optimization': 'Test different memory allocations',
        'timeout_optimization': 'Set appropriate timeouts',
        'concurrency_limits': 'Set concurrency limits to control costs',
        'reserved_capacity': 'Use provisioned concurrency for predictable workloads'
    }
    return optimization_strategies
```

### 2. S3 Cost Optimization
```python
def optimize_s3_costs():
    """
    Optimize S3 storage costs
    """
    cost_optimization = {
        'lifecycle_policies': 'Move old data to cheaper storage classes',
        'intelligent_tiering': 'Use S3 Intelligent Tiering for variable access patterns',
        'compression': 'Compress data to reduce storage costs',
        'cleanup': 'Regularly clean up temporary files'
    }
    return cost_optimization
```

## Best Practices Summary

### 1. Lambda Best Practices
- Right-size memory allocation based on workload
- Use connection pooling to reduce cold starts
- Implement proper error handling and retry logic
- Monitor and optimize execution time
- Use provisioned concurrency for critical functions

### 2. SQS Best Practices
- Use message batching for better throughput
- Set appropriate visibility timeouts
- Implement dead letter queues for error handling
- Monitor queue depth and processing rates

### 3. S3 Best Practices
- Use multipart uploads for large files
- Compress data before uploading
- Choose appropriate storage classes
- Implement lifecycle policies

### 4. Redshift Best Practices
- Use connection pooling
- Optimize table design with distribution and sort keys
- Use COPY command for bulk loading
- Regular maintenance (VACUUM, ANALYZE)

### 5. Overall Pipeline Best Practices
- Implement parallel processing where possible
- Use incremental processing to reduce data volume
- Monitor performance metrics continuously
- Optimize costs through right-sizing
- Implement comprehensive error handling

This performance optimization guide provides actionable strategies to improve the efficiency, reliability, and cost-effectiveness of your serverless ETL pipeline.

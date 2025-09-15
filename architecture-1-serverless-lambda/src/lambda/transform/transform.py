"""
Transform Lambda Function for Serverless ETL Architecture
Transforms data from S3 and applies business logic
"""

import json
import os
import boto3
from datetime import datetime
from typing import Dict, List, Any, Optional
import logging
import pandas as pd
from io import StringIO

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3 = boto3.client('s3')
sqs = boto3.client('sqs')

def lambda_handler(event, context):
    """
    Main Lambda handler for data transformation
    """
    try:
        logger.info(f"Starting transformation process. Event: {event}")
        
        # Get environment variables
        staging_bucket_name = os.environ['STAGING_BUCKET_NAME']
        processing_queue_url = os.environ['PROCESSING_QUEUE_URL']
        dlq_url = os.environ['DLQ_URL']
        
        # Process SQS messages
        for record in event['Records']:
            try:
                # Parse SQS message
                message_body = json.loads(record['body'])
                logger.info(f"Processing message: {message_body}")
                
                # Get data location from message
                data_location = message_body['data_location']
                bucket = data_location['bucket']
                key = data_location['key']
                
                # Download and transform data
                transformed_data = transform_data(bucket, key)
                
                if transformed_data:
                    # Store transformed data in S3
                    transformed_key = f"transformed/{datetime.now().strftime('%Y/%m/%d/%H')}/transformed_data_{context.aws_request_id}.json"
                    s3.put_object(
                        Bucket=staging_bucket_name,
                        Key=transformed_key,
                        Body=json.dumps(transformed_data, default=str),
                        ContentType='application/json'
                    )
                    
                    # Send to load queue (or trigger load Lambda directly)
                    load_message = {
                        'source': 'transform_lambda',
                        'timestamp': datetime.now().isoformat(),
                        'request_id': context.aws_request_id,
                        'data_location': {
                            'bucket': staging_bucket_name,
                            'key': transformed_key
                        },
                        'original_message': message_body
                    }
                    
                    # In this example, we'll trigger the load Lambda directly
                    # In a more complex setup, you might use another SQS queue
                    logger.info(f"Transformation completed. Data stored at: {transformed_key}")
                    
                else:
                    logger.warning("No data to transform")
                    
            except Exception as e:
                logger.error(f"Error processing individual record: {str(e)}")
                # Send to DLQ
                send_to_dlq(record, str(e), dlq_url)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Transformation completed successfully',
                'processedRecords': len(event['Records'])
            })
        }
        
    except Exception as e:
        logger.error(f"Error in transformation process: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': 'Transformation failed'
            })
        }

def transform_data(bucket: str, key: str) -> Optional[Dict[str, Any]]:
    """
    Transform data from S3
    """
    try:
        # Download data from S3
        response = s3.get_object(Bucket=bucket, Key=key)
        raw_data = json.loads(response['Body'].read().decode('utf-8'))
        
        logger.info(f"Downloaded data from S3: {bucket}/{key}")
        
        # Initialize transformed data structure
        transformed_data = {
            'metadata': {
                'transformation_timestamp': datetime.now().isoformat(),
                'source_file': key,
                'transformation_version': '1.0'
            },
            'transformed_records': []
        }
        
        # Transform RDS data
        if 'rds' in raw_data and raw_data['rds']:
            transformed_rds = transform_rds_data(raw_data['rds'])
            transformed_data['transformed_records'].extend(transformed_rds)
        
        # Transform API data
        if 'apis' in raw_data and raw_data['apis']:
            transformed_apis = transform_api_data(raw_data['apis'])
            transformed_data['transformed_records'].extend(transformed_apis)
        
        # Apply data quality checks
        transformed_data = apply_data_quality_checks(transformed_data)
        
        # Add summary statistics
        transformed_data['summary'] = {
            'total_records': len(transformed_data['transformed_records']),
            'transformation_timestamp': datetime.now().isoformat()
        }
        
        logger.info(f"Transformation completed. Total records: {transformed_data['summary']['total_records']}")
        return transformed_data
        
    except Exception as e:
        logger.error(f"Error transforming data: {str(e)}")
        return None

def transform_rds_data(rds_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Transform RDS data according to business rules
    """
    transformed_records = []
    
    for record in rds_data:
        try:
            # Apply business transformations
            transformed_record = {
                'record_type': 'order',
                'record_id': f"ORD_{record.get('order_id', '')}",
                'customer_id': record.get('customer_id'),
                'order_date': record.get('order_date'),
                'total_amount': float(record.get('total_amount', 0)),
                'status': record.get('status', '').upper(),
                'created_at': record.get('created_at'),
                'updated_at': record.get('updated_at'),
                'transformation_timestamp': datetime.now().isoformat(),
                
                # Derived fields
                'amount_category': get_amount_category(float(record.get('total_amount', 0))),
                'is_recent': is_recent_order(record.get('order_date')),
                'priority_score': calculate_priority_score(record)
            }
            
            transformed_records.append(transformed_record)
            
        except Exception as e:
            logger.error(f"Error transforming RDS record: {str(e)}")
            continue
    
    return transformed_records

def transform_api_data(api_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Transform API data according to business rules
    """
    transformed_records = []
    
    for api_record in api_data:
        try:
            if 'data' in api_record:
                for item in api_record['data']:
                    transformed_record = {
                        'record_type': 'product',
                        'record_id': f"PRD_{item.get('id', '')}",
                        'name': item.get('name', ''),
                        'price': float(item.get('price', 0)),
                        'category': item.get('category', ''),
                        'api_source': api_record.get('api_source', ''),
                        'source_timestamp': api_record.get('timestamp'),
                        'transformation_timestamp': datetime.now().isoformat(),
                        
                        # Derived fields
                        'price_category': get_price_category(float(item.get('price', 0))),
                        'is_premium': float(item.get('price', 0)) > 50.0
                    }
                    
                    transformed_records.append(transformed_record)
                    
        except Exception as e:
            logger.error(f"Error transforming API record: {str(e)}")
            continue
    
    return transformed_records

def get_amount_category(amount: float) -> str:
    """
    Categorize order amount
    """
    if amount < 50:
        return 'low'
    elif amount < 200:
        return 'medium'
    else:
        return 'high'

def get_price_category(price: float) -> str:
    """
    Categorize product price
    """
    if price < 20:
        return 'budget'
    elif price < 100:
        return 'standard'
    else:
        return 'premium'

def is_recent_order(order_date: str) -> bool:
    """
    Check if order is recent (within last 7 days)
    """
    try:
        if not order_date:
            return False
        
        order_dt = datetime.fromisoformat(order_date.replace('Z', '+00:00'))
        now = datetime.now(order_dt.tzinfo)
        days_diff = (now - order_dt).days
        
        return days_diff <= 7
    except:
        return False

def calculate_priority_score(record: Dict[str, Any]) -> int:
    """
    Calculate priority score for order processing
    """
    score = 0
    
    # Higher amount = higher priority
    amount = float(record.get('total_amount', 0))
    if amount > 500:
        score += 3
    elif amount > 200:
        score += 2
    elif amount > 50:
        score += 1
    
    # Recent orders = higher priority
    if is_recent_order(record.get('order_date')):
        score += 2
    
    # Status-based priority
    status = record.get('status', '').lower()
    if status == 'pending':
        score += 2
    elif status == 'processing':
        score += 1
    
    return min(score, 10)  # Cap at 10

def apply_data_quality_checks(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Apply data quality checks and cleaning
    """
    quality_issues = []
    cleaned_records = []
    
    for record in data['transformed_records']:
        issues = []
        
        # Check for required fields
        if not record.get('record_id'):
            issues.append('missing_record_id')
        
        if not record.get('record_type'):
            issues.append('missing_record_type')
        
        # Check for valid numeric values
        if 'total_amount' in record and record['total_amount'] < 0:
            issues.append('negative_amount')
        
        if 'price' in record and record['price'] < 0:
            issues.append('negative_price')
        
        # If no critical issues, include the record
        if not issues:
            cleaned_records.append(record)
        else:
            quality_issues.extend(issues)
    
    # Update data with cleaned records
    data['transformed_records'] = cleaned_records
    data['quality_issues'] = {
        'total_issues': len(quality_issues),
        'issue_types': list(set(quality_issues)),
        'records_removed': len(data['transformed_records']) - len(cleaned_records)
    }
    
    return data

def send_to_dlq(record: Dict[str, Any], error_message: str, dlq_url: str):
    """
    Send failed message to Dead Letter Queue
    """
    try:
        dlq_message = {
            'original_message': record,
            'error_message': error_message,
            'timestamp': datetime.now().isoformat(),
            'retry_count': record.get('attributes', {}).get('ApproximateReceiveCount', 0)
        }
        
        sqs.send_message(
            QueueUrl=dlq_url,
            MessageBody=json.dumps(dlq_message),
            MessageAttributes={
                'ErrorType': {
                    'StringValue': 'TransformationError',
                    'DataType': 'String'
                },
                'OriginalQueue': {
                    'StringValue': 'processing_queue',
                    'DataType': 'String'
                }
            }
        )
        
        logger.info(f"Message sent to DLQ: {dlq_message}")
        
    except Exception as e:
        logger.error(f"Error sending to DLQ: {str(e)}")

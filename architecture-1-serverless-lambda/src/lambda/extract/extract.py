"""
Extract Lambda Function for Serverless ETL Architecture
Extracts data from various sources (RDS, APIs, etc.) and sends to SQS
"""

import json
import os
import boto3
import psycopg2
import requests
from datetime import datetime
from typing import Dict, List, Any
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
sqs = boto3.client('sqs')
s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    Main Lambda handler for data extraction
    """
    try:
        logger.info(f"Starting extraction process. Event: {event}")
        
        # Get environment variables
        source_rds_endpoint = os.environ['SOURCE_RDS_ENDPOINT']
        processing_queue_url = os.environ['PROCESSING_QUEUE_URL']
        staging_bucket_name = os.environ['STAGING_BUCKET_NAME']
        
        # Extract data from different sources
        extracted_data = {}
        
        # Extract from RDS
        rds_data = extract_from_rds(source_rds_endpoint)
        extracted_data['rds'] = rds_data
        
        # Extract from APIs (example)
        api_data = extract_from_apis()
        extracted_data['apis'] = api_data
        
        # Store raw data in S3
        raw_data_key = f"raw/{datetime.now().strftime('%Y/%m/%d/%H')}/extracted_data_{context.aws_request_id}.json"
        s3.put_object(
            Bucket=staging_bucket_name,
            Key=raw_data_key,
            Body=json.dumps(extracted_data, default=str),
            ContentType='application/json'
        )
        
        # Send message to SQS for processing
        message_body = {
            'source': 'extract_lambda',
            'timestamp': datetime.now().isoformat(),
            'request_id': context.aws_request_id,
            'data_location': {
                'bucket': staging_bucket_name,
                'key': raw_data_key
            },
            'record_count': sum(len(data) if isinstance(data, list) else 1 for data in extracted_data.values())
        }
        
        response = sqs.send_message(
            QueueUrl=processing_queue_url,
            MessageBody=json.dumps(message_body),
            MessageAttributes={
                'Source': {
                    'StringValue': 'extract_lambda',
                    'DataType': 'String'
                },
                'Timestamp': {
                    'StringValue': datetime.now().isoformat(),
                    'DataType': 'String'
                }
            }
        )
        
        logger.info(f"Successfully sent message to SQS. MessageId: {response['MessageId']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Data extraction completed successfully',
                'messageId': response['MessageId'],
                'recordCount': message_body['record_count']
            })
        }
        
    except Exception as e:
        logger.error(f"Error in extraction process: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': 'Data extraction failed'
            })
        }

def extract_from_rds(endpoint: str) -> List[Dict[str, Any]]:
    """
    Extract data from RDS PostgreSQL database
    """
    try:
        # Parse endpoint to get host and port
        host = endpoint.split(':')[0]
        port = int(endpoint.split(':')[1]) if ':' in endpoint else 5432
        
        # Connect to database
        connection = psycopg2.connect(
            host=host,
            port=port,
            database='etl_source',
            user='etl_user',
            password=os.environ.get('DB_PASSWORD', 'default_password')
        )
        
        cursor = connection.cursor()
        
        # Example query - extract recent orders
        query = """
        SELECT 
            order_id,
            customer_id,
            order_date,
            total_amount,
            status,
            created_at,
            updated_at
        FROM orders 
        WHERE updated_at >= NOW() - INTERVAL '1 hour'
        ORDER BY updated_at DESC
        LIMIT 1000
        """
        
        cursor.execute(query)
        columns = [desc[0] for desc in cursor.description]
        rows = cursor.fetchall()
        
        # Convert to list of dictionaries
        data = []
        for row in rows:
            data.append(dict(zip(columns, row)))
        
        cursor.close()
        connection.close()
        
        logger.info(f"Extracted {len(data)} records from RDS")
        return data
        
    except Exception as e:
        logger.error(f"Error extracting from RDS: {str(e)}")
        return []

def extract_from_apis() -> List[Dict[str, Any]]:
    """
    Extract data from external APIs
    """
    try:
        api_data = []
        
        # Example: Extract from a sample API
        # In real implementation, you would have actual API endpoints
        sample_api_data = {
            'api_source': 'sample_api',
            'timestamp': datetime.now().isoformat(),
            'data': [
                {
                    'id': 1,
                    'name': 'Sample Product 1',
                    'price': 29.99,
                    'category': 'Electronics'
                },
                {
                    'id': 2,
                    'name': 'Sample Product 2',
                    'price': 19.99,
                    'category': 'Books'
                }
            ]
        }
        
        api_data.append(sample_api_data)
        
        logger.info(f"Extracted {len(api_data)} API records")
        return api_data
        
    except Exception as e:
        logger.error(f"Error extracting from APIs: {str(e)}")
        return []

def validate_extracted_data(data: Dict[str, Any]) -> bool:
    """
    Validate the extracted data
    """
    try:
        # Basic validation
        if not data:
            return False
            
        # Check if we have data from at least one source
        has_data = any(
            isinstance(value, list) and len(value) > 0 
            for value in data.values()
        )
        
        return has_data
        
    except Exception as e:
        logger.error(f"Error validating data: {str(e)}")
        return False

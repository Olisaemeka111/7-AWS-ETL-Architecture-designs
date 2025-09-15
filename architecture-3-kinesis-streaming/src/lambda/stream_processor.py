"""
Kinesis Stream Processor Lambda Function
Processes streaming data from Kinesis Data Streams and applies real-time transformations.
"""

import json
import base64
import boto3
import os
from datetime import datetime
from typing import Dict, List, Any
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
kinesis = boto3.client('kinesis')
s3 = boto3.client('s3')
firehose = boto3.client('firehose')

def lambda_handler(event, context):
    """
    Main Lambda handler for processing Kinesis stream records
    """
    try:
        logger.info(f"Processing {len(event['Records'])} records")
        
        processed_records = []
        failed_records = []
        
        for record in event['Records']:
            try:
                # Decode the Kinesis data
                payload = base64.b64decode(record['kinesis']['data']).decode('utf-8')
                data = json.loads(payload)
                
                # Process the record
                processed_data = process_record(data, record)
                
                if processed_data:
                    processed_records.append(processed_data)
                else:
                    failed_records.append({
                        'record': data,
                        'error': 'Processing failed'
                    })
                    
            except Exception as e:
                logger.error(f"Error processing record: {str(e)}")
                failed_records.append({
                    'record': record,
                    'error': str(e)
                })
        
        # Send processed records to destinations
        if processed_records:
            send_to_destinations(processed_records)
        
        # Handle failed records
        if failed_records:
            handle_failed_records(failed_records)
        
        # Send metrics
        send_processing_metrics(len(processed_records), len(failed_records))
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'processed': len(processed_records),
                'failed': len(failed_records)
            })
        }
        
    except Exception as e:
        logger.error(f"Lambda handler error: {str(e)}")
        raise

def process_record(data: Dict[str, Any], record: Dict[str, Any]) -> Dict[str, Any]:
    """
    Process individual record with business logic
    """
    try:
        # Add processing metadata
        processed_data = {
            **data,
            'processed_at': datetime.utcnow().isoformat(),
            'processing_lambda': 'stream_processor',
            'kinesis_sequence_number': record['kinesis']['sequenceNumber'],
            'kinesis_partition_key': record['kinesis']['partitionKey']
        }
        
        # Apply data transformations
        processed_data = apply_transformations(processed_data)
        
        # Validate data quality
        if validate_data_quality(processed_data):
            return processed_data
        else:
            logger.warning(f"Data quality validation failed for record: {data}")
            return None
            
    except Exception as e:
        logger.error(f"Error processing record: {str(e)}")
        return None

def apply_transformations(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Apply business logic transformations
    """
    try:
        # Example transformations
        if 'timestamp' in data:
            # Convert timestamp to standard format
            data['timestamp_utc'] = datetime.utcnow().isoformat()
        
        if 'user_id' in data:
            # Hash user ID for privacy
            import hashlib
            data['user_id_hash'] = hashlib.sha256(data['user_id'].encode()).hexdigest()
        
        if 'value' in data:
            # Apply business rules
            data['value_normalized'] = normalize_value(data['value'])
            data['value_category'] = categorize_value(data['value'])
        
        # Add derived fields
        data['processing_timestamp'] = datetime.utcnow().isoformat()
        data['data_version'] = '1.0'
        
        return data
        
    except Exception as e:
        logger.error(f"Error applying transformations: {str(e)}")
        return data

def normalize_value(value: Any) -> float:
    """
    Normalize numeric values
    """
    try:
        if isinstance(value, (int, float)):
            return float(value)
        elif isinstance(value, str):
            return float(value.replace(',', ''))
        else:
            return 0.0
    except (ValueError, TypeError):
        return 0.0

def categorize_value(value: float) -> str:
    """
    Categorize values based on business rules
    """
    if value < 10:
        return 'low'
    elif value < 100:
        return 'medium'
    elif value < 1000:
        return 'high'
    else:
        return 'very_high'

def validate_data_quality(data: Dict[str, Any]) -> bool:
    """
    Validate data quality
    """
    try:
        # Check required fields
        required_fields = ['user_id', 'event_type', 'timestamp']
        for field in required_fields:
            if field not in data or data[field] is None:
                logger.warning(f"Missing required field: {field}")
                return False
        
        # Check data types
        if not isinstance(data['user_id'], str):
            logger.warning("user_id must be a string")
            return False
        
        if not isinstance(data['event_type'], str):
            logger.warning("event_type must be a string")
            return False
        
        # Check for reasonable values
        if 'value' in data and isinstance(data['value'], (int, float)):
            if data['value'] < 0 or data['value'] > 1000000:
                logger.warning(f"Value out of reasonable range: {data['value']}")
                return False
        
        return True
        
    except Exception as e:
        logger.error(f"Error validating data quality: {str(e)}")
        return False

def send_to_destinations(records: List[Dict[str, Any]]):
    """
    Send processed records to various destinations
    """
    try:
        # Send to Kinesis Data Firehose
        send_to_firehose(records)
        
        # Send to S3 for backup
        send_to_s3(records)
        
        logger.info(f"Successfully sent {len(records)} records to destinations")
        
    except Exception as e:
        logger.error(f"Error sending to destinations: {str(e)}")
        raise

def send_to_firehose(records: List[Dict[str, Any]]):
    """
    Send records to Kinesis Data Firehose
    """
    try:
        firehose_stream_name = os.environ.get('FIREHOSE_STREAM_NAME', 'kinesis-streaming-etl-dev-s3-delivery')
        
        # Prepare records for Firehose
        firehose_records = []
        for record in records:
            firehose_records.append({
                'Data': json.dumps(record) + '\n'
            })
        
        # Send to Firehose
        response = firehose.put_record_batch(
            DeliveryStreamName=firehose_stream_name,
            Records=firehose_records
        )
        
        logger.info(f"Sent {len(firehose_records)} records to Firehose")
        
    except Exception as e:
        logger.error(f"Error sending to Firehose: {str(e)}")
        raise

def send_to_s3(records: List[Dict[str, Any]]):
    """
    Send records to S3 for backup
    """
    try:
        bucket_name = os.environ.get('S3_BUCKET', 'kinesis-streaming-etl-dev-processed-data')
        
        # Create filename with timestamp
        timestamp = datetime.utcnow().strftime('%Y/%m/%d/%H')
        filename = f"processed-data/{timestamp}/records_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.json"
        
        # Prepare data for S3
        s3_data = {
            'records': records,
            'metadata': {
                'processed_at': datetime.utcnow().isoformat(),
                'record_count': len(records),
                'lambda_function': 'stream_processor'
            }
        }
        
        # Upload to S3
        s3.put_object(
            Bucket=bucket_name,
            Key=filename,
            Body=json.dumps(s3_data, indent=2),
            ContentType='application/json'
        )
        
        logger.info(f"Uploaded {len(records)} records to S3: {filename}")
        
    except Exception as e:
        logger.error(f"Error sending to S3: {str(e)}")
        raise

def handle_failed_records(failed_records: List[Dict[str, Any]]):
    """
    Handle failed records
    """
    try:
        # Log failed records
        for failed_record in failed_records:
            logger.error(f"Failed record: {json.dumps(failed_record)}")
        
        # Send to dead letter queue or error storage
        bucket_name = os.environ.get('S3_BUCKET', 'kinesis-streaming-etl-dev-processed-data')
        timestamp = datetime.utcnow().strftime('%Y/%m/%d/%H')
        filename = f"failed-records/{timestamp}/failed_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.json"
        
        s3.put_object(
            Bucket=bucket_name,
            Key=filename,
            Body=json.dumps(failed_records, indent=2),
            ContentType='application/json'
        )
        
        logger.info(f"Stored {len(failed_records)} failed records in S3: {filename}")
        
    except Exception as e:
        logger.error(f"Error handling failed records: {str(e)}")
        raise

def send_processing_metrics(processed_count: int, failed_count: int):
    """
    Send processing metrics to CloudWatch
    """
    try:
        cloudwatch = boto3.client('cloudwatch')
        
        # Send custom metrics
        cloudwatch.put_metric_data(
            Namespace='ETL/StreamProcessing',
            MetricData=[
                {
                    'MetricName': 'RecordsProcessed',
                    'Value': processed_count,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'Function',
                            'Value': 'stream_processor'
                        }
                    ]
                },
                {
                    'MetricName': 'RecordsFailed',
                    'Value': failed_count,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'Function',
                            'Value': 'stream_processor'
                        }
                    ]
                },
                {
                    'MetricName': 'ProcessingSuccessRate',
                    'Value': (processed_count / (processed_count + failed_count)) * 100 if (processed_count + failed_count) > 0 else 100,
                    'Unit': 'Percent',
                    'Dimensions': [
                        {
                            'Name': 'Function',
                            'Value': 'stream_processor'
                        }
                    ]
                }
            ]
        )
        
        logger.info(f"Sent metrics: processed={processed_count}, failed={failed_count}")
        
    except Exception as e:
        logger.warning(f"Failed to send metrics: {str(e)}")

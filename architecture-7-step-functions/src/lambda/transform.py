import json
import boto3
import logging
from datetime import datetime
from typing import Dict, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Transform raw data from S3 and store processed data.
    
    Args:
        event: Lambda event containing S3 bucket and key information
        context: Lambda context object
        
    Returns:
        Dict containing processing results
    """
    try:
        logger.info(f"Transform function started with event: {json.dumps(event)}")
        
        # Extract parameters from event
        raw_bucket = event.get('raw_bucket', '')
        processed_bucket = event.get('processed_bucket', '')
        aggregated_bucket = event.get('aggregated_bucket', '')
        
        if not all([raw_bucket, processed_bucket, aggregated_bucket]):
            raise ValueError("Missing required bucket parameters")
        
        # Process raw data files
        processed_files = []
        aggregated_files = []
        
        # List objects in raw data bucket
        response = s3_client.list_objects_v2(Bucket=raw_bucket)
        
        if 'Contents' not in response:
            logger.info("No files found in raw data bucket")
            return {
                'statusCode': 200,
                'body': {
                    'message': 'No files to process',
                    'processed_files': [],
                    'aggregated_files': []
                }
            }
        
        for obj in response['Contents']:
            file_key = obj['Key']
            
            # Skip if not a data file
            if not file_key.endswith(('.json', '.csv', '.parquet')):
                continue
                
            logger.info(f"Processing file: {file_key}")
            
            # Download and process file
            processed_data = process_file(raw_bucket, file_key)
            
            if processed_data:
                # Store processed data
                processed_key = f"processed/{datetime.now().strftime('%Y/%m/%d')}/{file_key}"
                upload_processed_data(processed_bucket, processed_key, processed_data)
                processed_files.append(processed_key)
                
                # Create aggregated data
                aggregated_data = create_aggregated_data(processed_data)
                if aggregated_data:
                    aggregated_key = f"aggregated/{datetime.now().strftime('%Y/%m/%d')}/{file_key}"
                    upload_aggregated_data(aggregated_bucket, aggregated_key, aggregated_data)
                    aggregated_files.append(aggregated_key)
        
        logger.info(f"Transform completed. Processed: {len(processed_files)}, Aggregated: {len(aggregated_files)}")
        
        return {
            'statusCode': 200,
            'body': {
                'message': 'Transform completed successfully',
                'processed_files': processed_files,
                'aggregated_files': aggregated_files,
                'timestamp': datetime.now().isoformat()
            }
        }
        
    except Exception as e:
        logger.error(f"Error in transform function: {str(e)}")
        raise e

def process_file(bucket: str, key: str) -> Dict[str, Any]:
    """
    Process a single file from S3.
    
    Args:
        bucket: S3 bucket name
        key: S3 object key
        
    Returns:
        Processed data dictionary
    """
    try:
        # Download file from S3
        response = s3_client.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read().decode('utf-8')
        
        # Parse based on file type
        if key.endswith('.json'):
            data = json.loads(content)
        elif key.endswith('.csv'):
            data = parse_csv(content)
        else:
            # For parquet files, we would need additional libraries
            logger.warning(f"Unsupported file type: {key}")
            return None
        
        # Apply transformations
        processed_data = apply_transformations(data)
        
        return processed_data
        
    except Exception as e:
        logger.error(f"Error processing file {key}: {str(e)}")
        return None

def parse_csv(content: str) -> Dict[str, Any]:
    """
    Parse CSV content into structured data.
    
    Args:
        content: CSV content as string
        
    Returns:
        Parsed data dictionary
    """
    lines = content.strip().split('\n')
    if not lines:
        return {}
    
    headers = lines[0].split(',')
    data = []
    
    for line in lines[1:]:
        values = line.split(',')
        if len(values) == len(headers):
            row = dict(zip(headers, values))
            data.append(row)
    
    return {'data': data, 'headers': headers}

def apply_transformations(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Apply data transformations.
    
    Args:
        data: Raw data dictionary
        
    Returns:
        Transformed data dictionary
    """
    try:
        # Add metadata
        data['metadata'] = {
            'processed_at': datetime.now().isoformat(),
            'transformation_version': '1.0'
        }
        
        # Clean and validate data
        if 'data' in data and isinstance(data['data'], list):
            cleaned_data = []
            for item in data['data']:
                if isinstance(item, dict):
                    # Clean string values
                    cleaned_item = {}
                    for key, value in item.items():
                        if isinstance(value, str):
                            cleaned_item[key] = value.strip()
                        else:
                            cleaned_item[key] = value
                    cleaned_data.append(cleaned_item)
            data['data'] = cleaned_data
        
        # Add data quality metrics
        data['quality_metrics'] = {
            'total_records': len(data.get('data', [])),
            'processed_at': datetime.now().isoformat()
        }
        
        return data
        
    except Exception as e:
        logger.error(f"Error applying transformations: {str(e)}")
        return data

def create_aggregated_data(processed_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Create aggregated data from processed data.
    
    Args:
        processed_data: Processed data dictionary
        
    Returns:
        Aggregated data dictionary
    """
    try:
        if 'data' not in processed_data or not processed_data['data']:
            return None
        
        # Simple aggregation example
        aggregated = {
            'summary': {
                'total_records': len(processed_data['data']),
                'aggregated_at': datetime.now().isoformat()
            },
            'metadata': processed_data.get('metadata', {}),
            'quality_metrics': processed_data.get('quality_metrics', {})
        }
        
        # Add field-level aggregations if data exists
        if processed_data['data']:
            sample_record = processed_data['data'][0]
            aggregated['field_summary'] = {
                'fields': list(sample_record.keys()),
                'field_count': len(sample_record.keys())
            }
        
        return aggregated
        
    except Exception as e:
        logger.error(f"Error creating aggregated data: {str(e)}")
        return None

def upload_processed_data(bucket: str, key: str, data: Dict[str, Any]) -> bool:
    """
    Upload processed data to S3.
    
    Args:
        bucket: S3 bucket name
        key: S3 object key
        data: Data to upload
        
    Returns:
        True if successful, False otherwise
    """
    try:
        s3_client.put_object(
            Bucket=bucket,
            Key=key,
            Body=json.dumps(data, indent=2),
            ContentType='application/json'
        )
        logger.info(f"Uploaded processed data to s3://{bucket}/{key}")
        return True
        
    except Exception as e:
        logger.error(f"Error uploading processed data: {str(e)}")
        return False

def upload_aggregated_data(bucket: str, key: str, data: Dict[str, Any]) -> bool:
    """
    Upload aggregated data to S3.
    
    Args:
        bucket: S3 bucket name
        key: S3 object key
        data: Data to upload
        
    Returns:
        True if successful, False otherwise
    """
    try:
        s3_client.put_object(
            Bucket=bucket,
            Key=key,
            Body=json.dumps(data, indent=2),
            ContentType='application/json'
        )
        logger.info(f"Uploaded aggregated data to s3://{bucket}/{key}")
        return True
        
    except Exception as e:
        logger.error(f"Error uploading aggregated data: {str(e)}")
        return False

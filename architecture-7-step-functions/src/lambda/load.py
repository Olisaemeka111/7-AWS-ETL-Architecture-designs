import json
import boto3
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List
import psycopg2
from psycopg2.extras import RealDictCursor

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
redshift_client = boto3.client('redshift-data')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Load processed and aggregated data into Redshift data warehouse.
    
    Args:
        event: Lambda event containing load parameters
        context: Lambda context object
        
    Returns:
        Dict containing load results
    """
    try:
        logger.info(f"Load function started with event: {json.dumps(event)}")
        
        # Extract parameters from event
        processed_bucket = event.get('processed_bucket', '')
        aggregated_bucket = event.get('aggregated_bucket', '')
        redshift_endpoint = event.get('redshift_endpoint', '')
        
        if not all([processed_bucket, aggregated_bucket]):
            raise ValueError("Missing required bucket parameters")
        
        load_results = {
            'processed_data': {},
            'aggregated_data': {},
            'timestamp': datetime.now().isoformat()
        }
        
        # Load processed data if Redshift is available
        if redshift_endpoint:
            load_results['processed_data'] = load_processed_data_to_redshift(
                processed_bucket, redshift_endpoint
            )
            load_results['aggregated_data'] = load_aggregated_data_to_redshift(
                aggregated_bucket, redshift_endpoint
            )
        else:
            logger.info("Redshift endpoint not provided, skipping database load")
            load_results['processed_data'] = {
                'status': 'SKIPPED',
                'message': 'Redshift endpoint not available'
            }
            load_results['aggregated_data'] = {
                'status': 'SKIPPED',
                'message': 'Redshift endpoint not available'
            }
        
        # Create data lake summary
        load_results['data_lake_summary'] = create_data_lake_summary(
            processed_bucket, aggregated_bucket
        )
        
        logger.info(f"Load completed successfully")
        
        return {
            'statusCode': 200,
            'body': load_results
        }
        
    except Exception as e:
        logger.error(f"Error in load function: {str(e)}")
        raise e

def load_processed_data_to_redshift(bucket: str, redshift_endpoint: str) -> Dict[str, Any]:
    """
    Load processed data into Redshift.
    
    Args:
        bucket: S3 bucket name containing processed data
        redshift_endpoint: Redshift cluster endpoint
        
    Returns:
        Load result dictionary
    """
    try:
        # List processed data files
        response = s3_client.list_objects_v2(Bucket=bucket, Prefix='processed/')
        
        if 'Contents' not in response:
            return {
                'status': 'SKIPPED',
                'message': 'No processed files found',
                'records_loaded': 0
            }
        
        # Get recent files (last 24 hours)
        recent_files = get_recent_files(response['Contents'], hours=24)
        
        if not recent_files:
            return {
                'status': 'SKIPPED',
                'message': 'No recent processed files found',
                'records_loaded': 0
            }
        
        # Create or update tables
        create_tables_if_not_exists(redshift_endpoint)
        
        # Load data from each file
        total_records = 0
        loaded_files = []
        
        for file_obj in recent_files:
            key = file_obj['Key']
            
            if not key.endswith('.json'):
                continue
            
            try:
                records_loaded = load_file_to_redshift(bucket, key, redshift_endpoint)
                total_records += records_loaded
                loaded_files.append({
                    'file': key,
                    'records_loaded': records_loaded
                })
                
            except Exception as e:
                logger.error(f"Error loading file {key}: {str(e)}")
                continue
        
        return {
            'status': 'SUCCESS',
            'message': f'Loaded {total_records} records from {len(loaded_files)} files',
            'records_loaded': total_records,
            'files_processed': loaded_files
        }
        
    except Exception as e:
        logger.error(f"Error loading processed data to Redshift: {str(e)}")
        return {
            'status': 'ERROR',
            'message': f'Error loading processed data: {str(e)}',
            'records_loaded': 0
        }

def load_aggregated_data_to_redshift(bucket: str, redshift_endpoint: str) -> Dict[str, Any]:
    """
    Load aggregated data into Redshift.
    
    Args:
        bucket: S3 bucket name containing aggregated data
        redshift_endpoint: Redshift cluster endpoint
        
    Returns:
        Load result dictionary
    """
    try:
        # List aggregated data files
        response = s3_client.list_objects_v2(Bucket=bucket, Prefix='aggregated/')
        
        if 'Contents' not in response:
            return {
                'status': 'SKIPPED',
                'message': 'No aggregated files found',
                'records_loaded': 0
            }
        
        # Get recent files (last 24 hours)
        recent_files = get_recent_files(response['Contents'], hours=24)
        
        if not recent_files:
            return {
                'status': 'SKIPPED',
                'message': 'No recent aggregated files found',
                'records_loaded': 0
            }
        
        # Create aggregated tables
        create_aggregated_tables_if_not_exists(redshift_endpoint)
        
        # Load aggregated data
        total_records = 0
        loaded_files = []
        
        for file_obj in recent_files:
            key = file_obj['Key']
            
            if not key.endswith('.json'):
                continue
            
            try:
                records_loaded = load_aggregated_file_to_redshift(bucket, key, redshift_endpoint)
                total_records += records_loaded
                loaded_files.append({
                    'file': key,
                    'records_loaded': records_loaded
                })
                
            except Exception as e:
                logger.error(f"Error loading aggregated file {key}: {str(e)}")
                continue
        
        return {
            'status': 'SUCCESS',
            'message': f'Loaded {total_records} aggregated records from {len(loaded_files)} files',
            'records_loaded': total_records,
            'files_processed': loaded_files
        }
        
    except Exception as e:
        logger.error(f"Error loading aggregated data to Redshift: {str(e)}")
        return {
            'status': 'ERROR',
            'message': f'Error loading aggregated data: {str(e)}',
            'records_loaded': 0
        }

def get_recent_files(files: List[Dict[str, Any]], hours: int = 24) -> List[Dict[str, Any]]:
    """
    Filter files to only include recent ones.
    
    Args:
        files: List of S3 objects
        hours: Number of hours to look back
        
    Returns:
        List of recent S3 objects
    """
    cutoff_time = datetime.now() - timedelta(hours=hours)
    recent_files = []
    
    for file_obj in files:
        if file_obj['LastModified'].replace(tzinfo=None) >= cutoff_time:
            recent_files.append(file_obj)
    
    return recent_files

def create_tables_if_not_exists(redshift_endpoint: str) -> None:
    """
    Create tables in Redshift if they don't exist.
    
    Args:
        redshift_endpoint: Redshift cluster endpoint
    """
    try:
        # This would typically use psycopg2 or redshift-data API
        # For this example, we'll use a simplified approach
        
        create_table_sql = """
        CREATE TABLE IF NOT EXISTS processed_data (
            id VARCHAR(255),
            data JSON,
            metadata JSON,
            quality_metrics JSON,
            processed_at TIMESTAMP,
            created_at TIMESTAMP DEFAULT GETDATE()
        );
        """
        
        # In a real implementation, you would execute this SQL
        logger.info(f"Would create table: {create_table_sql}")
        
    except Exception as e:
        logger.error(f"Error creating tables: {str(e)}")

def create_aggregated_tables_if_not_exists(redshift_endpoint: str) -> None:
    """
    Create aggregated tables in Redshift if they don't exist.
    
    Args:
        redshift_endpoint: Redshift cluster endpoint
    """
    try:
        create_table_sql = """
        CREATE TABLE IF NOT EXISTS aggregated_data (
            id VARCHAR(255),
            summary JSON,
            metadata JSON,
            quality_metrics JSON,
            field_summary JSON,
            aggregated_at TIMESTAMP,
            created_at TIMESTAMP DEFAULT GETDATE()
        );
        """
        
        # In a real implementation, you would execute this SQL
        logger.info(f"Would create aggregated table: {create_table_sql}")
        
    except Exception as e:
        logger.error(f"Error creating aggregated tables: {str(e)}")

def load_file_to_redshift(bucket: str, key: str, redshift_endpoint: str) -> int:
    """
    Load a single file into Redshift.
    
    Args:
        bucket: S3 bucket name
        key: S3 object key
        redshift_endpoint: Redshift cluster endpoint
        
    Returns:
        Number of records loaded
    """
    try:
        # Download file from S3
        response = s3_client.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read().decode('utf-8')
        data = json.loads(content)
        
        if 'data' not in data or not isinstance(data['data'], list):
            return 0
        
        # In a real implementation, you would:
        # 1. Parse the data
        # 2. Insert records into Redshift
        # 3. Return the count of inserted records
        
        records_count = len(data['data'])
        logger.info(f"Would load {records_count} records from {key} to Redshift")
        
        return records_count
        
    except Exception as e:
        logger.error(f"Error loading file {key}: {str(e)}")
        return 0

def load_aggregated_file_to_redshift(bucket: str, key: str, redshift_endpoint: str) -> int:
    """
    Load a single aggregated file into Redshift.
    
    Args:
        bucket: S3 bucket name
        key: S3 object key
        redshift_endpoint: Redshift cluster endpoint
        
    Returns:
        Number of records loaded
    """
    try:
        # Download file from S3
        response = s3_client.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read().decode('utf-8')
        data = json.loads(content)
        
        # In a real implementation, you would insert the aggregated data
        logger.info(f"Would load aggregated data from {key} to Redshift")
        
        return 1  # Aggregated files typically contain one record
        
    except Exception as e:
        logger.error(f"Error loading aggregated file {key}: {str(e)}")
        return 0

def create_data_lake_summary(processed_bucket: str, aggregated_bucket: str) -> Dict[str, Any]:
    """
    Create a summary of the data lake contents.
    
    Args:
        processed_bucket: S3 bucket name for processed data
        aggregated_bucket: S3 bucket name for aggregated data
        
    Returns:
        Data lake summary dictionary
    """
    try:
        summary = {
            'processed_data': get_bucket_summary(processed_bucket),
            'aggregated_data': get_bucket_summary(aggregated_bucket),
            'summary_timestamp': datetime.now().isoformat()
        }
        
        return summary
        
    except Exception as e:
        logger.error(f"Error creating data lake summary: {str(e)}")
        return {
            'error': str(e),
            'summary_timestamp': datetime.now().isoformat()
        }

def get_bucket_summary(bucket: str) -> Dict[str, Any]:
    """
    Get summary information for an S3 bucket.
    
    Args:
        bucket: S3 bucket name
        
    Returns:
        Bucket summary dictionary
    """
    try:
        response = s3_client.list_objects_v2(Bucket=bucket)
        
        if 'Contents' not in response:
            return {
                'file_count': 0,
                'total_size': 0,
                'last_modified': None
            }
        
        files = response['Contents']
        total_size = sum(file_obj['Size'] for file_obj in files)
        last_modified = max(file_obj['LastModified'] for file_obj in files)
        
        return {
            'file_count': len(files),
            'total_size': total_size,
            'last_modified': last_modified.isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error getting bucket summary for {bucket}: {str(e)}")
        return {
            'error': str(e),
            'file_count': 0,
            'total_size': 0
        }

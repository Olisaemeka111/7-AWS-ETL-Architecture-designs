import json
import boto3
import logging
from datetime import datetime
from typing import Dict, Any, List

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Validate processed data for quality and completeness.
    
    Args:
        event: Lambda event containing validation parameters
        context: Lambda context object
        
    Returns:
        Dict containing validation results
    """
    try:
        logger.info(f"Validation function started with event: {json.dumps(event)}")
        
        # Extract parameters from event
        processed_bucket = event.get('processed_bucket', '')
        
        if not processed_bucket:
            raise ValueError("Missing processed_bucket parameter")
        
        # Perform validation
        validation_results = perform_validation(processed_bucket)
        
        # Check if validation passed
        validation_passed = all(
            result['status'] == 'PASS' 
            for result in validation_results.values()
        )
        
        logger.info(f"Validation completed. Passed: {validation_passed}")
        
        return {
            'statusCode': 200,
            'body': {
                'message': 'Validation completed',
                'validation_passed': validation_passed,
                'validation_results': validation_results,
                'timestamp': datetime.now().isoformat()
            }
        }
        
    except Exception as e:
        logger.error(f"Error in validation function: {str(e)}")
        raise e

def perform_validation(bucket: str) -> Dict[str, Any]:
    """
    Perform comprehensive data validation.
    
    Args:
        bucket: S3 bucket name containing processed data
        
    Returns:
        Dictionary of validation results
    """
    validation_results = {}
    
    try:
        # List processed data files
        response = s3_client.list_objects_v2(Bucket=bucket, Prefix='processed/')
        
        if 'Contents' not in response:
            validation_results['file_existence'] = {
                'status': 'FAIL',
                'message': 'No processed files found',
                'details': 'No files found in processed data bucket'
            }
            return validation_results
        
        # Validate file structure
        validation_results['file_structure'] = validate_file_structure(response['Contents'])
        
        # Validate data quality
        validation_results['data_quality'] = validate_data_quality(bucket, response['Contents'])
        
        # Validate data completeness
        validation_results['data_completeness'] = validate_data_completeness(bucket, response['Contents'])
        
        # Validate data consistency
        validation_results['data_consistency'] = validate_data_consistency(bucket, response['Contents'])
        
        return validation_results
        
    except Exception as e:
        logger.error(f"Error performing validation: {str(e)}")
        validation_results['validation_error'] = {
            'status': 'FAIL',
            'message': f'Validation error: {str(e)}',
            'details': 'Error occurred during validation process'
        }
        return validation_results

def validate_file_structure(files: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Validate file structure and naming conventions.
    
    Args:
        files: List of S3 objects
        
    Returns:
        Validation result dictionary
    """
    try:
        issues = []
        
        for file_obj in files:
            key = file_obj['Key']
            
            # Check file extension
            if not key.endswith(('.json', '.csv', '.parquet')):
                issues.append(f"Invalid file extension: {key}")
            
            # Check file size
            if file_obj['Size'] == 0:
                issues.append(f"Empty file: {key}")
            
            # Check naming convention (should be in processed/YYYY/MM/DD/ format)
            parts = key.split('/')
            if len(parts) < 4 or parts[0] != 'processed':
                issues.append(f"Invalid file path structure: {key}")
        
        if issues:
            return {
                'status': 'FAIL',
                'message': f'File structure validation failed with {len(issues)} issues',
                'details': issues
            }
        else:
            return {
                'status': 'PASS',
                'message': 'File structure validation passed',
                'details': f'Validated {len(files)} files'
            }
            
    except Exception as e:
        return {
            'status': 'FAIL',
            'message': f'File structure validation error: {str(e)}',
            'details': 'Error occurred during file structure validation'
        }

def validate_data_quality(bucket: str, files: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Validate data quality metrics.
    
    Args:
        bucket: S3 bucket name
        files: List of S3 objects
        
    Returns:
        Validation result dictionary
    """
    try:
        quality_issues = []
        total_records = 0
        
        for file_obj in files[:5]:  # Sample first 5 files
            key = file_obj['Key']
            
            if not key.endswith('.json'):
                continue
                
            try:
                # Download and parse file
                response = s3_client.get_object(Bucket=bucket, Key=key)
                content = response['Body'].read().decode('utf-8')
                data = json.loads(content)
                
                # Check for required fields
                if 'data' not in data:
                    quality_issues.append(f"Missing 'data' field in {key}")
                    continue
                
                if 'metadata' not in data:
                    quality_issues.append(f"Missing 'metadata' field in {key}")
                
                if 'quality_metrics' not in data:
                    quality_issues.append(f"Missing 'quality_metrics' field in {key}")
                
                # Check data records
                if isinstance(data['data'], list):
                    total_records += len(data['data'])
                    
                    # Sample validation of records
                    for i, record in enumerate(data['data'][:10]):  # Sample first 10 records
                        if not isinstance(record, dict):
                            quality_issues.append(f"Invalid record type at index {i} in {key}")
                        elif not record:  # Empty record
                            quality_issues.append(f"Empty record at index {i} in {key}")
                
            except json.JSONDecodeError as e:
                quality_issues.append(f"Invalid JSON in {key}: {str(e)}")
            except Exception as e:
                quality_issues.append(f"Error processing {key}: {str(e)}")
        
        if quality_issues:
            return {
                'status': 'FAIL',
                'message': f'Data quality validation failed with {len(quality_issues)} issues',
                'details': quality_issues
            }
        else:
            return {
                'status': 'PASS',
                'message': 'Data quality validation passed',
                'details': f'Validated {total_records} records across {len(files)} files'
            }
            
    except Exception as e:
        return {
            'status': 'FAIL',
            'message': f'Data quality validation error: {str(e)}',
            'details': 'Error occurred during data quality validation'
        }

def validate_data_completeness(bucket: str, files: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Validate data completeness.
    
    Args:
        bucket: S3 bucket name
        files: List of S3 objects
        
    Returns:
        Validation result dictionary
    """
    try:
        completeness_issues = []
        
        # Check if we have data for recent dates
        today = datetime.now()
        recent_dates = []
        
        for i in range(7):  # Check last 7 days
            date_str = (today - timedelta(days=i)).strftime('%Y/%m/%d')
            recent_dates.append(f"processed/{date_str}/")
        
        for date_prefix in recent_dates:
            date_files = [f for f in files if f['Key'].startswith(date_prefix)]
            if not date_files:
                completeness_issues.append(f"No data found for date: {date_prefix}")
        
        if completeness_issues:
            return {
                'status': 'WARN',
                'message': f'Data completeness validation found {len(completeness_issues)} issues',
                'details': completeness_issues
            }
        else:
            return {
                'status': 'PASS',
                'message': 'Data completeness validation passed',
                'details': f'Data found for all recent dates'
            }
            
    except Exception as e:
        return {
            'status': 'FAIL',
            'message': f'Data completeness validation error: {str(e)}',
            'details': 'Error occurred during data completeness validation'
        }

def validate_data_consistency(bucket: str, files: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Validate data consistency across files.
    
    Args:
        bucket: S3 bucket name
        files: List of S3 objects
        
    Returns:
        Validation result dictionary
    """
    try:
        consistency_issues = []
        schema_samples = {}
        
        # Sample files to check schema consistency
        for file_obj in files[:3]:  # Check first 3 files
            key = file_obj['Key']
            
            if not key.endswith('.json'):
                continue
                
            try:
                response = s3_client.get_object(Bucket=bucket, Key=key)
                content = response['Body'].read().decode('utf-8')
                data = json.loads(content)
                
                if 'data' in data and isinstance(data['data'], list) and data['data']:
                    # Get schema from first record
                    first_record = data['data'][0]
                    schema = set(first_record.keys())
                    schema_samples[key] = schema
                    
            except Exception as e:
                consistency_issues.append(f"Error reading {key}: {str(e)}")
        
        # Check schema consistency
        if len(schema_samples) > 1:
            base_schema = list(schema_samples.values())[0]
            for key, schema in schema_samples.items():
                if schema != base_schema:
                    consistency_issues.append(f"Schema mismatch in {key}")
        
        if consistency_issues:
            return {
                'status': 'WARN',
                'message': f'Data consistency validation found {len(consistency_issues)} issues',
                'details': consistency_issues
            }
        else:
            return {
                'status': 'PASS',
                'message': 'Data consistency validation passed',
                'details': f'Consistent schema across {len(schema_samples)} files'
            }
            
    except Exception as e:
        return {
            'status': 'FAIL',
            'message': f'Data consistency validation error: {str(e)}',
            'details': 'Error occurred during data consistency validation'
        }

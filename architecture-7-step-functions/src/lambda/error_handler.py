import json
import boto3
import logging
from datetime import datetime
from typing import Dict, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
sns_client = boto3.client('sns')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Handle errors from the ETL pipeline and send notifications.
    
    Args:
        event: Lambda event containing error information
        context: Lambda context object
        
    Returns:
        Dict containing error handling results
    """
    try:
        logger.info(f"Error handler started with event: {json.dumps(event)}")
        
        # Extract error information
        error_info = extract_error_info(event)
        
        # Log the error
        log_error(error_info)
        
        # Send notification
        notification_result = send_error_notification(error_info)
        
        # Determine retry strategy
        retry_strategy = determine_retry_strategy(error_info)
        
        logger.info(f"Error handling completed. Retry strategy: {retry_strategy}")
        
        return {
            'statusCode': 200,
            'body': {
                'message': 'Error handled successfully',
                'error_info': error_info,
                'notification_sent': notification_result['sent'],
                'retry_strategy': retry_strategy,
                'timestamp': datetime.now().isoformat()
            }
        }
        
    except Exception as e:
        logger.error(f"Error in error handler function: {str(e)}")
        # Don't raise the exception to avoid infinite loops
        return {
            'statusCode': 500,
            'body': {
                'message': 'Error handler failed',
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
        }

def extract_error_info(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Extract error information from the event.
    
    Args:
        event: Lambda event containing error information
        
    Returns:
        Dictionary containing structured error information
    """
    try:
        error_info = {
            'error_type': 'UNKNOWN',
            'error_message': 'Unknown error',
            'state_name': event.get('state_name', 'UNKNOWN'),
            'retry_count': event.get('retry_count', 0),
            'timestamp': datetime.now().isoformat(),
            'context': {}
        }
        
        # Extract error from different possible event structures
        if 'error' in event:
            error = event['error']
            if isinstance(error, dict):
                error_info['error_type'] = error.get('Error', 'UNKNOWN')
                error_info['error_message'] = error.get('Cause', 'Unknown error')
            elif isinstance(error, str):
                error_info['error_message'] = error
        
        # Extract additional context
        if 'Input' in event:
            error_info['context']['input'] = event['Input']
        
        if 'Execution' in event:
            error_info['context']['execution'] = event['Execution']
        
        # Determine error category
        error_info['error_category'] = categorize_error(error_info)
        
        return error_info
        
    except Exception as e:
        logger.error(f"Error extracting error info: {str(e)}")
        return {
            'error_type': 'EXTRACTION_ERROR',
            'error_message': f'Failed to extract error info: {str(e)}',
            'state_name': 'UNKNOWN',
            'retry_count': 0,
            'timestamp': datetime.now().isoformat(),
            'error_category': 'SYSTEM_ERROR'
        }

def categorize_error(error_info: Dict[str, Any]) -> str:
    """
    Categorize the error for better handling.
    
    Args:
        error_info: Dictionary containing error information
        
    Returns:
        Error category string
    """
    error_type = error_info.get('error_type', '').upper()
    error_message = error_info.get('error_message', '').upper()
    
    # Network/Connectivity errors
    if any(keyword in error_message for keyword in ['TIMEOUT', 'CONNECTION', 'NETWORK', 'DNS']):
        return 'NETWORK_ERROR'
    
    # AWS Service errors
    if any(keyword in error_type for keyword in ['AWS', 'S3', 'LAMBDA', 'GLUE', 'EMR']):
        return 'AWS_SERVICE_ERROR'
    
    # Data validation errors
    if any(keyword in error_message for keyword in ['VALIDATION', 'SCHEMA', 'FORMAT', 'PARSE']):
        return 'DATA_ERROR'
    
    # Resource errors
    if any(keyword in error_message for keyword in ['MEMORY', 'DISK', 'CPU', 'RESOURCE']):
        return 'RESOURCE_ERROR'
    
    # Permission errors
    if any(keyword in error_message for keyword in ['PERMISSION', 'ACCESS', 'AUTHORIZATION', 'FORBIDDEN']):
        return 'PERMISSION_ERROR'
    
    # Rate limiting errors
    if any(keyword in error_message for keyword in ['RATE', 'THROTTLE', 'LIMIT']):
        return 'RATE_LIMIT_ERROR'
    
    return 'UNKNOWN_ERROR'

def log_error(error_info: Dict[str, Any]) -> None:
    """
    Log the error with appropriate level and details.
    
    Args:
        error_info: Dictionary containing error information
    """
    try:
        log_message = {
            'error_type': error_info['error_type'],
            'error_message': error_info['error_message'],
            'state_name': error_info['state_name'],
            'retry_count': error_info['retry_count'],
            'error_category': error_info['error_category'],
            'timestamp': error_info['timestamp']
        }
        
        # Log with appropriate level based on error category
        if error_info['error_category'] in ['SYSTEM_ERROR', 'PERMISSION_ERROR']:
            logger.error(f"Critical error: {json.dumps(log_message)}")
        elif error_info['error_category'] in ['AWS_SERVICE_ERROR', 'NETWORK_ERROR']:
            logger.warning(f"Service error: {json.dumps(log_message)}")
        else:
            logger.info(f"Error occurred: {json.dumps(log_message)}")
            
    except Exception as e:
        logger.error(f"Error logging error: {str(e)}")

def send_error_notification(error_info: Dict[str, Any]) -> Dict[str, Any]:
    """
    Send error notification via SNS.
    
    Args:
        error_info: Dictionary containing error information
        
    Returns:
        Notification result dictionary
    """
    try:
        # Get SNS topic ARN from environment or event
        topic_arn = event.get('sns_topic_arn', '')
        
        if not topic_arn:
            logger.warning("No SNS topic ARN provided, skipping notification")
            return {'sent': False, 'reason': 'No SNS topic ARN'}
        
        # Create notification message
        message = create_notification_message(error_info)
        
        # Send notification
        response = sns_client.publish(
            TopicArn=topic_arn,
            Message=json.dumps(message, indent=2),
            Subject=f"ETL Pipeline Error - {error_info['state_name']}"
        )
        
        logger.info(f"Error notification sent successfully: {response['MessageId']}")
        
        return {
            'sent': True,
            'message_id': response['MessageId'],
            'topic_arn': topic_arn
        }
        
    except Exception as e:
        logger.error(f"Error sending notification: {str(e)}")
        return {
            'sent': False,
            'error': str(e)
        }

def create_notification_message(error_info: Dict[str, Any]) -> Dict[str, Any]:
    """
    Create a structured notification message.
    
    Args:
        error_info: Dictionary containing error information
        
    Returns:
        Notification message dictionary
    """
    return {
        'alert_type': 'ETL_PIPELINE_ERROR',
        'severity': get_error_severity(error_info),
        'error_details': {
            'error_type': error_info['error_type'],
            'error_message': error_info['error_message'],
            'state_name': error_info['state_name'],
            'retry_count': error_info['retry_count'],
            'error_category': error_info['error_category']
        },
        'context': error_info.get('context', {}),
        'recommended_actions': get_recommended_actions(error_info),
        'timestamp': error_info['timestamp']
    }

def get_error_severity(error_info: Dict[str, Any]) -> str:
    """
    Determine error severity level.
    
    Args:
        error_info: Dictionary containing error information
        
    Returns:
        Severity level string
    """
    error_category = error_info.get('error_category', 'UNKNOWN_ERROR')
    retry_count = error_info.get('retry_count', 0)
    
    # Critical errors
    if error_category in ['SYSTEM_ERROR', 'PERMISSION_ERROR']:
        return 'CRITICAL'
    
    # High severity for repeated failures
    if retry_count >= 3:
        return 'HIGH'
    
    # Medium severity for service errors
    if error_category in ['AWS_SERVICE_ERROR', 'NETWORK_ERROR']:
        return 'MEDIUM'
    
    # Low severity for data errors
    if error_category in ['DATA_ERROR', 'RATE_LIMIT_ERROR']:
        return 'LOW'
    
    return 'MEDIUM'

def get_recommended_actions(error_info: Dict[str, Any]) -> list:
    """
    Get recommended actions based on error type.
    
    Args:
        error_info: Dictionary containing error information
        
    Returns:
        List of recommended actions
    """
    error_category = error_info.get('error_category', 'UNKNOWN_ERROR')
    retry_count = error_info.get('retry_count', 0)
    
    actions = []
    
    if error_category == 'NETWORK_ERROR':
        actions.extend([
            'Check network connectivity',
            'Verify AWS service status',
            'Retry with exponential backoff'
        ])
    
    elif error_category == 'AWS_SERVICE_ERROR':
        actions.extend([
            'Check AWS service health dashboard',
            'Verify IAM permissions',
            'Check service quotas and limits'
        ])
    
    elif error_category == 'DATA_ERROR':
        actions.extend([
            'Validate input data format',
            'Check data schema compliance',
            'Review data transformation logic'
        ])
    
    elif error_category == 'RESOURCE_ERROR':
        actions.extend([
            'Increase Lambda memory allocation',
            'Optimize data processing logic',
            'Consider using larger instance types'
        ])
    
    elif error_category == 'PERMISSION_ERROR':
        actions.extend([
            'Review IAM policies',
            'Check resource permissions',
            'Verify cross-account access'
        ])
    
    elif error_category == 'RATE_LIMIT_ERROR':
        actions.extend([
            'Implement exponential backoff',
            'Reduce request frequency',
            'Request quota increase if needed'
        ])
    
    # Add general actions for repeated failures
    if retry_count >= 3:
        actions.extend([
            'Investigate root cause',
            'Consider manual intervention',
            'Review error patterns'
        ])
    
    return actions

def determine_retry_strategy(error_info: Dict[str, Any]) -> Dict[str, Any]:
    """
    Determine the retry strategy based on error type and count.
    
    Args:
        error_info: Dictionary containing error information
        
    Returns:
        Retry strategy dictionary
    """
    error_category = error_info.get('error_category', 'UNKNOWN_ERROR')
    retry_count = error_info.get('retry_count', 0)
    
    # Maximum retry counts by error category
    max_retries = {
        'NETWORK_ERROR': 5,
        'AWS_SERVICE_ERROR': 3,
        'DATA_ERROR': 1,
        'RESOURCE_ERROR': 2,
        'PERMISSION_ERROR': 0,  # Don't retry permission errors
        'RATE_LIMIT_ERROR': 5,
        'UNKNOWN_ERROR': 3
    }
    
    max_retry_count = max_retries.get(error_category, 3)
    
    if retry_count >= max_retry_count:
        return {
            'should_retry': False,
            'reason': f'Maximum retry count ({max_retry_count}) exceeded',
            'next_action': 'MANUAL_INTERVENTION'
        }
    
    # Calculate backoff delay
    base_delay = 2 ** retry_count  # Exponential backoff
    max_delay = 300  # 5 minutes max
    
    delay = min(base_delay, max_delay)
    
    return {
        'should_retry': True,
        'retry_count': retry_count + 1,
        'delay_seconds': delay,
        'next_action': 'RETRY'
    }

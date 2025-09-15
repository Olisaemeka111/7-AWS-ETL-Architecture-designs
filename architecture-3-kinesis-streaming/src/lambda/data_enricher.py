"""
Data Enricher Lambda Function
Enriches streaming data with additional information from lookup tables and external sources.
"""

import json
import base64
import boto3
import os
from datetime import datetime
from typing import Dict, List, Any, Optional
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.client('dynamodb')
s3 = boto3.client('s3')
kinesis = boto3.client('kinesis')

def lambda_handler(event, context):
    """
    Main Lambda handler for enriching Kinesis stream records
    """
    try:
        logger.info(f"Enriching {len(event['Records'])} records")
        
        enriched_records = []
        failed_records = []
        
        for record in event['Records']:
            try:
                # Decode the Kinesis data
                payload = base64.b64decode(record['kinesis']['data']).decode('utf-8')
                data = json.loads(payload)
                
                # Enrich the record
                enriched_data = enrich_record(data, record)
                
                if enriched_data:
                    enriched_records.append(enriched_data)
                else:
                    failed_records.append({
                        'record': data,
                        'error': 'Enrichment failed'
                    })
                    
            except Exception as e:
                logger.error(f"Error enriching record: {str(e)}")
                failed_records.append({
                    'record': record,
                    'error': str(e)
                })
        
        # Send enriched records to output stream
        if enriched_records:
            send_to_output_stream(enriched_records)
        
        # Handle failed records
        if failed_records:
            handle_failed_records(failed_records)
        
        # Send metrics
        send_enrichment_metrics(len(enriched_records), len(failed_records))
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'enriched': len(enriched_records),
                'failed': len(failed_records)
            })
        }
        
    except Exception as e:
        logger.error(f"Lambda handler error: {str(e)}")
        raise

def enrich_record(data: Dict[str, Any], record: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """
    Enrich individual record with additional data
    """
    try:
        # Start with original data
        enriched_data = data.copy()
        
        # Add enrichment metadata
        enriched_data['enriched_at'] = datetime.utcnow().isoformat()
        enriched_data['enrichment_lambda'] = 'data_enricher'
        
        # Perform different types of enrichment
        enriched_data = enrich_user_data(enriched_data)
        enriched_data = enrich_geographic_data(enriched_data)
        enriched_data = enrich_business_data(enriched_data)
        enriched_data = enrich_external_data(enriched_data)
        
        # Validate enriched data
        if validate_enriched_data(enriched_data):
            return enriched_data
        else:
            logger.warning(f"Enriched data validation failed for record: {data}")
            return None
            
    except Exception as e:
        logger.error(f"Error enriching record: {str(e)}")
        return None

def enrich_user_data(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Enrich data with user information
    """
    try:
        if 'user_id' in data:
            user_id = data['user_id']
            
            # Get user data from DynamoDB
            user_data = get_user_data(user_id)
            
            if user_data:
                # Add user enrichment
                data['user_segment'] = user_data.get('segment', 'unknown')
                data['user_tier'] = user_data.get('tier', 'standard')
                data['user_region'] = user_data.get('region', 'unknown')
                data['user_preferences'] = user_data.get('preferences', {})
                
                # Calculate user lifetime value
                data['user_ltv'] = calculate_user_ltv(user_data)
                
                # Add user behavior patterns
                data['user_behavior_score'] = calculate_behavior_score(user_data)
        
        return data
        
    except Exception as e:
        logger.error(f"Error enriching user data: {str(e)}")
        return data

def enrich_geographic_data(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Enrich data with geographic information
    """
    try:
        # Extract IP address or location data
        ip_address = data.get('ip_address')
        coordinates = data.get('coordinates')
        
        if ip_address:
            # Get geographic data from IP
            geo_data = get_geographic_data(ip_address)
            
            if geo_data:
                data['country'] = geo_data.get('country', 'unknown')
                data['region'] = geo_data.get('region', 'unknown')
                data['city'] = geo_data.get('city', 'unknown')
                data['timezone'] = geo_data.get('timezone', 'UTC')
                data['isp'] = geo_data.get('isp', 'unknown')
        
        if coordinates:
            # Get location-based data
            location_data = get_location_data(coordinates)
            
            if location_data:
                data['location_type'] = location_data.get('type', 'unknown')
                data['location_category'] = location_data.get('category', 'unknown')
                data['nearby_landmarks'] = location_data.get('landmarks', [])
        
        return data
        
    except Exception as e:
        logger.error(f"Error enriching geographic data: {str(e)}")
        return data

def enrich_business_data(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Enrich data with business-specific information
    """
    try:
        # Add business context
        data['business_hour'] = is_business_hour(data.get('timestamp'))
        data['day_of_week'] = get_day_of_week(data.get('timestamp'))
        data['season'] = get_season(data.get('timestamp'))
        
        # Add product/service information
        if 'product_id' in data:
            product_data = get_product_data(data['product_id'])
            if product_data:
                data['product_category'] = product_data.get('category', 'unknown')
                data['product_price'] = product_data.get('price', 0)
                data['product_rating'] = product_data.get('rating', 0)
        
        # Add campaign information
        if 'campaign_id' in data:
            campaign_data = get_campaign_data(data['campaign_id'])
            if campaign_data:
                data['campaign_type'] = campaign_data.get('type', 'unknown')
                data['campaign_budget'] = campaign_data.get('budget', 0)
                data['campaign_target_audience'] = campaign_data.get('target_audience', 'unknown')
        
        return data
        
    except Exception as e:
        logger.error(f"Error enriching business data: {str(e)}")
        return data

def enrich_external_data(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Enrich data with external API data
    """
    try:
        # Add weather data if location is available
        if 'city' in data or 'coordinates' in data:
            weather_data = get_weather_data(data)
            if weather_data:
                data['weather_condition'] = weather_data.get('condition', 'unknown')
                data['temperature'] = weather_data.get('temperature', 0)
                data['humidity'] = weather_data.get('humidity', 0)
        
        # Add market data if relevant
        if 'product_id' in data:
            market_data = get_market_data(data['product_id'])
            if market_data:
                data['market_trend'] = market_data.get('trend', 'stable')
                data['competitor_price'] = market_data.get('competitor_price', 0)
                data['market_demand'] = market_data.get('demand', 'medium')
        
        return data
        
    except Exception as e:
        logger.error(f"Error enriching external data: {str(e)}")
        return data

def get_user_data(user_id: str) -> Optional[Dict[str, Any]]:
    """
    Get user data from DynamoDB
    """
    try:
        table_name = os.environ.get('ENRICHMENT_TABLE', 'user-enrichment-table')
        
        response = dynamodb.get_item(
            TableName=table_name,
            Key={
                'user_id': {'S': user_id}
            }
        )
        
        if 'Item' in response:
            # Convert DynamoDB item to regular dict
            user_data = {}
            for key, value in response['Item'].items():
                if 'S' in value:
                    user_data[key] = value['S']
                elif 'N' in value:
                    user_data[key] = float(value['N'])
                elif 'M' in value:
                    user_data[key] = {k: v.get('S', v.get('N', v)) for k, v in value['M'].items()}
            
            return user_data
        
        return None
        
    except Exception as e:
        logger.error(f"Error getting user data: {str(e)}")
        return None

def get_geographic_data(ip_address: str) -> Optional[Dict[str, Any]]:
    """
    Get geographic data from IP address
    """
    try:
        # This would typically call an external API or use a local database
        # For demo purposes, return mock data
        return {
            'country': 'US',
            'region': 'CA',
            'city': 'San Francisco',
            'timezone': 'America/Los_Angeles',
            'isp': 'Example ISP'
        }
        
    except Exception as e:
        logger.error(f"Error getting geographic data: {str(e)}")
        return None

def get_location_data(coordinates: Dict[str, float]) -> Optional[Dict[str, Any]]:
    """
    Get location-based data from coordinates
    """
    try:
        # This would typically call a mapping service
        # For demo purposes, return mock data
        return {
            'type': 'commercial',
            'category': 'shopping_center',
            'landmarks': ['Central Park', 'Main Street']
        }
        
    except Exception as e:
        logger.error(f"Error getting location data: {str(e)}")
        return None

def get_product_data(product_id: str) -> Optional[Dict[str, Any]]:
    """
    Get product data from database
    """
    try:
        # This would typically query a product database
        # For demo purposes, return mock data
        return {
            'category': 'electronics',
            'price': 299.99,
            'rating': 4.5
        }
        
    except Exception as e:
        logger.error(f"Error getting product data: {str(e)}")
        return None

def get_campaign_data(campaign_id: str) -> Optional[Dict[str, Any]]:
    """
    Get campaign data from database
    """
    try:
        # This would typically query a campaign database
        # For demo purposes, return mock data
        return {
            'type': 'email',
            'budget': 10000,
            'target_audience': 'premium_users'
        }
        
    except Exception as e:
        logger.error(f"Error getting campaign data: {str(e)}")
        return None

def get_weather_data(data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """
    Get weather data from external API
    """
    try:
        # This would typically call a weather API
        # For demo purposes, return mock data
        return {
            'condition': 'sunny',
            'temperature': 72,
            'humidity': 45
        }
        
    except Exception as e:
        logger.error(f"Error getting weather data: {str(e)}")
        return None

def get_market_data(product_id: str) -> Optional[Dict[str, Any]]:
    """
    Get market data from external API
    """
    try:
        # This would typically call a market data API
        # For demo purposes, return mock data
        return {
            'trend': 'increasing',
            'competitor_price': 279.99,
            'demand': 'high'
        }
        
    except Exception as e:
        logger.error(f"Error getting market data: {str(e)}")
        return None

def calculate_user_ltv(user_data: Dict[str, Any]) -> float:
    """
    Calculate user lifetime value
    """
    try:
        # Simple LTV calculation
        total_spent = user_data.get('total_spent', 0)
        purchase_count = user_data.get('purchase_count', 1)
        avg_order_value = total_spent / purchase_count if purchase_count > 0 else 0
        
        return avg_order_value * 12  # Annual projection
        
    except Exception as e:
        logger.error(f"Error calculating user LTV: {str(e)}")
        return 0.0

def calculate_behavior_score(user_data: Dict[str, Any]) -> float:
    """
    Calculate user behavior score
    """
    try:
        # Simple behavior score calculation
        score = 0.0
        
        # Add points for various behaviors
        if user_data.get('is_premium', False):
            score += 20
        
        if user_data.get('referral_count', 0) > 0:
            score += 10
        
        if user_data.get('last_login_days', 0) < 7:
            score += 15
        
        return min(score, 100.0)  # Cap at 100
        
    except Exception as e:
        logger.error(f"Error calculating behavior score: {str(e)}")
        return 0.0

def is_business_hour(timestamp: str) -> bool:
    """
    Check if timestamp is during business hours
    """
    try:
        if not timestamp:
            return False
        
        dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        hour = dt.hour
        
        # Business hours: 9 AM to 5 PM
        return 9 <= hour <= 17
        
    except Exception as e:
        logger.error(f"Error checking business hour: {str(e)}")
        return False

def get_day_of_week(timestamp: str) -> str:
    """
    Get day of week from timestamp
    """
    try:
        if not timestamp:
            return 'unknown'
        
        dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        return dt.strftime('%A')
        
    except Exception as e:
        logger.error(f"Error getting day of week: {str(e)}")
        return 'unknown'

def get_season(timestamp: str) -> str:
    """
    Get season from timestamp
    """
    try:
        if not timestamp:
            return 'unknown'
        
        dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        month = dt.month
        
        if month in [12, 1, 2]:
            return 'winter'
        elif month in [3, 4, 5]:
            return 'spring'
        elif month in [6, 7, 8]:
            return 'summer'
        else:
            return 'fall'
        
    except Exception as e:
        logger.error(f"Error getting season: {str(e)}")
        return 'unknown'

def validate_enriched_data(data: Dict[str, Any]) -> bool:
    """
    Validate enriched data
    """
    try:
        # Check if enrichment was successful
        if 'enriched_at' not in data:
            return False
        
        # Check for required enriched fields
        required_enriched_fields = ['user_segment', 'business_hour']
        for field in required_enriched_fields:
            if field not in data:
                logger.warning(f"Missing enriched field: {field}")
        
        return True
        
    except Exception as e:
        logger.error(f"Error validating enriched data: {str(e)}")
        return False

def send_to_output_stream(records: List[Dict[str, Any]]):
    """
    Send enriched records to output Kinesis stream
    """
    try:
        output_stream_name = os.environ.get('OUTPUT_STREAM_NAME', 'kinesis-streaming-etl-dev-analytics-stream')
        
        # Send records to output stream
        for record in records:
            kinesis.put_record(
                StreamName=output_stream_name,
                Data=json.dumps(record),
                PartitionKey=record.get('user_id', 'default')
            )
        
        logger.info(f"Sent {len(records)} enriched records to output stream")
        
    except Exception as e:
        logger.error(f"Error sending to output stream: {str(e)}")
        raise

def handle_failed_records(failed_records: List[Dict[str, Any]]):
    """
    Handle failed enrichment records
    """
    try:
        # Log failed records
        for failed_record in failed_records:
            logger.error(f"Failed enrichment record: {json.dumps(failed_record)}")
        
        # Store failed records for analysis
        bucket_name = os.environ.get('S3_BUCKET', 'kinesis-streaming-etl-dev-processed-data')
        timestamp = datetime.utcnow().strftime('%Y/%m/%d/%H')
        filename = f"failed-enrichments/{timestamp}/failed_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.json"
        
        s3.put_object(
            Bucket=bucket_name,
            Key=filename,
            Body=json.dumps(failed_records, indent=2),
            ContentType='application/json'
        )
        
        logger.info(f"Stored {len(failed_records)} failed enrichment records in S3: {filename}")
        
    except Exception as e:
        logger.error(f"Error handling failed records: {str(e)}")
        raise

def send_enrichment_metrics(enriched_count: int, failed_count: int):
    """
    Send enrichment metrics to CloudWatch
    """
    try:
        cloudwatch = boto3.client('cloudwatch')
        
        # Send custom metrics
        cloudwatch.put_metric_data(
            Namespace='ETL/DataEnrichment',
            MetricData=[
                {
                    'MetricName': 'RecordsEnriched',
                    'Value': enriched_count,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'Function',
                            'Value': 'data_enricher'
                        }
                    ]
                },
                {
                    'MetricName': 'EnrichmentFailures',
                    'Value': failed_count,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'Function',
                            'Value': 'data_enricher'
                        }
                    ]
                },
                {
                    'MetricName': 'EnrichmentSuccessRate',
                    'Value': (enriched_count / (enriched_count + failed_count)) * 100 if (enriched_count + failed_count) > 0 else 100,
                    'Unit': 'Percent',
                    'Dimensions': [
                        {
                            'Name': 'Function',
                            'Value': 'data_enricher'
                        }
                    ]
                }
            ]
        )
        
        logger.info(f"Sent enrichment metrics: enriched={enriched_count}, failed={failed_count}")
        
    except Exception as e:
        logger.warning(f"Failed to send enrichment metrics: {str(e)}")

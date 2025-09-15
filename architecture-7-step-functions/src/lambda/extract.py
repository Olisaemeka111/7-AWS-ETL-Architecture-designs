#!/usr/bin/env python3
"""
Architecture 7: Step Functions ETL - Extract Lambda Function

This Lambda function handles data extraction from various sources as part of the
Step Functions ETL pipeline. It supports multiple data sources and formats.

Author: AWS ETL Architecture Team
Version: 1.0
"""

import json
import logging
import os
import boto3
import pandas as pd
import requests
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import time

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
s3_client = boto3.client('s3')
secrets_manager = boto3.client('secretsmanager')
cloudwatch = boto3.client('cloudwatch')

class DataExtractor:
    """
    Data extraction class for Step Functions ETL pipeline
    """
    
    def __init__(self):
        """Initialize the data extractor"""
        self.logger = logging.getLogger(self.__class__.__name__)
        
        # Configuration
        self.config = self._load_config()
        
        # Metrics
        self.metrics = {
            'records_extracted': 0,
            'files_processed': 0,
            'errors': 0,
            'start_time': datetime.now()
        }
    
    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from environment variables"""
        try:
            config = {
                'aws_region': os.environ.get('AWS_DEFAULT_REGION', 'us-east-1'),
                's3_raw_bucket': os.environ.get('S3_RAW_BUCKET'),
                's3_processed_bucket': os.environ.get('S3_PROCESSED_BUCKET'),
                'extraction_mode': os.environ.get('EXTRACTION_MODE', 'full'),
                'batch_size': int(os.environ.get('BATCH_SIZE', '1000')),
                'max_retries': int(os.environ.get('MAX_RETRIES', '3')),
                'retry_delay': int(os.environ.get('RETRY_DELAY', '5'))
            }
            
            self.logger.info(f"Configuration loaded: {config}")
            return config
            
        except Exception as e:
            self.logger.error(f"Error loading configuration: {str(e)}")
            raise
    
    def _get_secret(self, secret_name: str) -> str:
        """Retrieve secret from AWS Secrets Manager"""
        try:
            response = secrets_manager.get_secret_value(SecretId=secret_name)
            return response['SecretString']
        except Exception as e:
            self.logger.error(f"Error retrieving secret {secret_name}: {str(e)}")
            raise
    
    def extract_from_s3(self, source_config: Dict[str, Any]) -> pd.DataFrame:
        """
        Extract data from S3
        
        Args:
            source_config: S3 source configuration
            
        Returns:
            pd.DataFrame: Extracted data
        """
        try:
            self.logger.info("Starting S3 data extraction")
            
            bucket = source_config.get('bucket', self.config['s3_raw_bucket'])
            prefix = source_config.get('prefix', '')
            file_format = source_config.get('format', 'parquet')
            
            # List objects in S3
            paginator = s3_client.get_paginator('list_objects_v2')
            page_iterator = paginator.paginate(Bucket=bucket, Prefix=prefix)
            
            dataframes = []
            
            for page in page_iterator:
                if 'Contents' in page:
                    for obj in page['Contents']:
                        key = obj['Key']
                        
                        # Skip directories
                        if key.endswith('/'):
                            continue
                        
                        try:
                            # Download and read file
                            response = s3_client.get_object(Bucket=bucket, Key=key)
                            
                            if file_format.lower() == 'parquet':
                                df = pd.read_parquet(response['Body'])
                            elif file_format.lower() == 'csv':
                                df = pd.read_csv(response['Body'])
                            elif file_format.lower() == 'json':
                                df = pd.read_json(response['Body'])
                            else:
                                self.logger.warning(f"Unsupported file format: {file_format}")
                                continue
                            
                            dataframes.append(df)
                            self.metrics['files_processed'] += 1
                            self.logger.info(f"Processed file: {key}")
                            
                        except Exception as e:
                            self.logger.error(f"Error processing file {key}: {str(e)}")
                            self.metrics['errors'] += 1
                            continue
            
            if dataframes:
                combined_df = pd.concat(dataframes, ignore_index=True)
                self.metrics['records_extracted'] += len(combined_df)
                self.logger.info(f"Extracted {len(combined_df)} records from S3")
                return combined_df
            else:
                self.logger.warning("No data found in S3")
                return pd.DataFrame()
                
        except Exception as e:
            self.logger.error(f"Error in S3 extraction: {str(e)}")
            raise
    
    def extract_from_api(self, source_config: Dict[str, Any]) -> pd.DataFrame:
        """
        Extract data from API
        
        Args:
            source_config: API source configuration
            
        Returns:
            pd.DataFrame: Extracted data
        """
        try:
            self.logger.info("Starting API extraction")
            
            endpoint = source_config['endpoint']
            api_key_secret = source_config.get('api_key_secret')
            
            # Get API key from Secrets Manager
            api_key = self._get_secret(api_key_secret) if api_key_secret else None
            
            # Prepare headers
            headers = source_config.get('headers', {})
            if api_key:
                headers['Authorization'] = f"Bearer {api_key}"
            
            # Prepare parameters
            params = source_config.get('params', {})
            
            # Make API request
            response = requests.get(
                endpoint,
                headers=headers,
                params=params,
                timeout=30
            )
            response.raise_for_status()
            
            # Parse response
            data = response.json()
            
            # Convert to DataFrame
            if isinstance(data, list):
                df = pd.DataFrame(data)
            elif isinstance(data, dict):
                if 'data' in data:
                    df = pd.DataFrame(data['data'])
                else:
                    df = pd.DataFrame([data])
            else:
                raise ValueError("Unsupported API response format")
            
            self.metrics['records_extracted'] += len(df)
            self.logger.info(f"Extracted {len(df)} records from API")
            return df
            
        except Exception as e:
            self.logger.error(f"Error in API extraction: {str(e)}")
            raise
    
    def extract_from_database(self, source_config: Dict[str, Any]) -> pd.DataFrame:
        """
        Extract data from database
        
        Args:
            source_config: Database source configuration
            
        Returns:
            pd.DataFrame: Extracted data
        """
        try:
            self.logger.info("Starting database extraction")
            
            # This is a placeholder for database extraction
            # In a real implementation, you would connect to the database
            # and execute the query
            
            # For now, return sample data
            sample_data = {
                'id': [1, 2, 3, 4, 5],
                'name': ['John', 'Jane', 'Bob', 'Alice', 'Charlie'],
                'email': ['john@example.com', 'jane@example.com', 'bob@example.com', 'alice@example.com', 'charlie@example.com'],
                'created_at': [datetime.now() - timedelta(days=i) for i in range(5)]
            }
            
            df = pd.DataFrame(sample_data)
            self.metrics['records_extracted'] += len(df)
            self.logger.info(f"Extracted {len(df)} records from database")
            return df
            
        except Exception as e:
            self.logger.error(f"Error in database extraction: {str(e)}")
            raise
    
    def extract_data(self, extraction_config: Dict[str, Any]) -> pd.DataFrame:
        """
        Extract data based on configuration
        
        Args:
            extraction_config: Extraction configuration
            
        Returns:
            pd.DataFrame: Extracted data
        """
        try:
            source_type = extraction_config.get('type', 's3')
            
            self.logger.info(f"Starting data extraction from {source_type}")
            
            if source_type == 's3':
                return self.extract_from_s3(extraction_config)
            elif source_type == 'api':
                return self.extract_from_api(extraction_config)
            elif source_type == 'database':
                return self.extract_from_database(extraction_config)
            else:
                raise ValueError(f"Unsupported source type: {source_type}")
                
        except Exception as e:
            self.logger.error(f"Error in data extraction: {str(e)}")
            raise
    
    def save_extracted_data(self, df: pd.DataFrame, output_config: Dict[str, Any]) -> str:
        """
        Save extracted data to S3
        
        Args:
            df: Extracted DataFrame
            output_config: Output configuration
            
        Returns:
            str: S3 object key
        """
        try:
            bucket = output_config.get('bucket', self.config['s3_raw_bucket'])
            key = output_config.get('key', f"extracted-data/{datetime.now().strftime('%Y/%m/%d')}/data_{datetime.now().strftime('%Y%m%d_%H%M%S')}.parquet")
            format_type = output_config.get('format', 'parquet')
            
            # Convert DataFrame to bytes
            if format_type == 'parquet':
                buffer = df.to_parquet(index=False)
            elif format_type == 'csv':
                buffer = df.to_csv(index=False).encode('utf-8')
            elif format_type == 'json':
                buffer = df.to_json(orient='records').encode('utf-8')
            else:
                raise ValueError(f"Unsupported output format: {format_type}")
            
            # Upload to S3
            s3_client.put_object(
                Bucket=bucket,
                Key=key,
                Body=buffer,
                ContentType='application/octet-stream'
            )
            
            self.logger.info(f"Saved extracted data to S3: s3://{bucket}/{key}")
            return key
            
        except Exception as e:
            self.logger.error(f"Error saving extracted data: {str(e)}")
            raise
    
    def send_metrics(self):
        """Send custom metrics to CloudWatch"""
        try:
            end_time = datetime.now()
            processing_time = (end_time - self.metrics['start_time']).total_seconds()
            
            # Send custom metrics
            cloudwatch.put_metric_data(
                Namespace='ETL/StepFunctions',
                MetricData=[
                    {
                        'MetricName': 'RecordsExtracted',
                        'Value': self.metrics['records_extracted'],
                        'Unit': 'Count',
                        'Dimensions': [
                            {
                                'Name': 'FunctionName',
                                'Value': 'etl-extract'
                            }
                        ]
                    },
                    {
                        'MetricName': 'FilesProcessed',
                        'Value': self.metrics['files_processed'],
                        'Unit': 'Count',
                        'Dimensions': [
                            {
                                'Name': 'FunctionName',
                                'Value': 'etl-extract'
                            }
                        ]
                    },
                    {
                        'MetricName': 'ExtractionErrors',
                        'Value': self.metrics['errors'],
                        'Unit': 'Count',
                        'Dimensions': [
                            {
                                'Name': 'FunctionName',
                                'Value': 'etl-extract'
                            }
                        ]
                    },
                    {
                        'MetricName': 'ExtractionTime',
                        'Value': processing_time,
                        'Unit': 'Seconds',
                        'Dimensions': [
                            {
                                'Name': 'FunctionName',
                                'Value': 'etl-extract'
                            }
                        ]
                    }
                ]
            )
            
            self.logger.info("Metrics sent to CloudWatch successfully")
            
        except Exception as e:
            self.logger.error(f"Error sending metrics: {str(e)}")
    
    def process_extraction(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """
        Process the complete extraction
        
        Args:
            event: Lambda event data
            
        Returns:
            Dict: Processing results
        """
        try:
            self.logger.info("Starting extraction processing")
            
            # Get extraction configuration from event
            extraction_config = event.get('extraction_config', {})
            output_config = event.get('output_config', {})
            
            if not extraction_config:
                raise ValueError("Extraction configuration is required")
            
            # Extract data
            df = self.extract_data(extraction_config)
            
            # Save extracted data
            s3_key = self.save_extracted_data(df, output_config)
            
            # Send metrics
            self.send_metrics()
            
            result = {
                'status': 'success',
                'records_extracted': len(df),
                'files_processed': self.metrics['files_processed'],
                'errors': self.metrics['errors'],
                's3_key': s3_key,
                'processing_time': (datetime.now() - self.metrics['start_time']).total_seconds(),
                'timestamp': datetime.now().isoformat()
            }
            
            self.logger.info(f"Extraction completed successfully: {result}")
            return result
            
        except Exception as e:
            self.logger.error(f"Extraction failed: {str(e)}")
            self.send_metrics()
            raise


def lambda_handler(event, context):
    """
    Lambda handler function
    
    Args:
        event: Lambda event data
        context: Lambda context
        
    Returns:
        Dict: Processing results
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Initialize extractor
        extractor = DataExtractor()
        
        # Process extraction
        result = extractor.process_extraction(event)
        
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Lambda execution failed: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            })
        }

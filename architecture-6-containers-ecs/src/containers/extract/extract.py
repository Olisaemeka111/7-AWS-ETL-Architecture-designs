#!/usr/bin/env python3
"""
Architecture 6: Containerized ETL with ECS - Extract Container

This container handles data extraction from various sources including:
- S3 buckets
- RDS databases
- External APIs
- File systems

Author: AWS ETL Architecture Team
Version: 1.0
"""

import os
import sys
import json
import logging
import boto3
import pandas as pd
import psycopg2
import requests
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from urllib.parse import urlparse
import time
from flask import Flask, request, jsonify

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app for health checks
app = Flask(__name__)

class DataExtractor:
    """
    Data extraction class for handling various data sources
    """
    
    def __init__(self):
        """Initialize the data extractor"""
        self.logger = logging.getLogger(self.__class__.__name__)
        
        # AWS clients
        self.s3_client = boto3.client('s3')
        self.secrets_manager = boto3.client('secretsmanager')
        
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
                's3_bucket': os.environ.get('S3_BUCKET'),
                'database_host': os.environ.get('DATABASE_HOST'),
                'database_name': os.environ.get('DATABASE_NAME'),
                'database_username': os.environ.get('DATABASE_USERNAME'),
                'database_password_secret': os.environ.get('DATABASE_PASSWORD_SECRET'),
                'api_endpoint': os.environ.get('API_ENDPOINT'),
                'api_key_secret': os.environ.get('API_KEY_SECRET'),
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
            response = self.secrets_manager.get_secret_value(SecretId=secret_name)
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
            
            bucket = source_config.get('bucket', self.config['s3_bucket'])
            prefix = source_config.get('prefix', '')
            file_format = source_config.get('format', 'parquet')
            
            # List objects in S3
            paginator = self.s3_client.get_paginator('list_objects_v2')
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
                            response = self.s3_client.get_object(Bucket=bucket, Key=key)
                            
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
            
            # Get database connection parameters
            host = source_config.get('host', self.config['database_host'])
            database = source_config.get('database', self.config['database_name'])
            username = source_config.get('username', self.config['database_username'])
            password_secret = source_config.get('password_secret', self.config['database_password_secret'])
            
            # Get password from Secrets Manager
            password = self._get_secret(password_secret)
            
            # Build query
            query = source_config.get('query')
            if not query:
                table_name = source_config['table_name']
                columns = source_config.get('columns', '*')
                where_clause = source_config.get('where_clause', '')
                order_by = source_config.get('order_by', '')
                
                query = f"SELECT {columns} FROM {table_name}"
                if where_clause:
                    query += f" WHERE {where_clause}"
                if order_by:
                    query += f" ORDER BY {order_by}"
            
            # Connect to database and execute query
            connection = psycopg2.connect(
                host=host,
                database=database,
                user=username,
                password=password,
                port=5432
            )
            
            try:
                df = pd.read_sql_query(query, connection)
                self.metrics['records_extracted'] += len(df)
                self.logger.info(f"Extracted {len(df)} records from database")
                return df
                
            finally:
                connection.close()
                
        except Exception as e:
            self.logger.error(f"Error in database extraction: {str(e)}")
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
            
            endpoint = source_config.get('endpoint', self.config['api_endpoint'])
            api_key_secret = source_config.get('api_key_secret', self.config['api_key_secret'])
            
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
    
    def extract_from_files(self, source_config: Dict[str, Any]) -> pd.DataFrame:
        """
        Extract data from local files
        
        Args:
            source_config: File source configuration
            
        Returns:
            pd.DataFrame: Extracted data
        """
        try:
            self.logger.info("Starting file extraction")
            
            file_path = source_config['file_path']
            file_format = source_config.get('format', 'csv')
            
            # Read file based on format
            if file_format.lower() == 'csv':
                df = pd.read_csv(file_path)
            elif file_format.lower() == 'json':
                df = pd.read_json(file_path)
            elif file_format.lower() == 'parquet':
                df = pd.read_parquet(file_path)
            elif file_format.lower() == 'excel':
                df = pd.read_excel(file_path)
            else:
                raise ValueError(f"Unsupported file format: {file_format}")
            
            self.metrics['records_extracted'] += len(df)
            self.logger.info(f"Extracted {len(df)} records from file")
            return df
            
        except Exception as e:
            self.logger.error(f"Error in file extraction: {str(e)}")
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
            elif source_type == 'database':
                return self.extract_from_database(extraction_config)
            elif source_type == 'api':
                return self.extract_from_api(extraction_config)
            elif source_type == 'file':
                return self.extract_from_files(extraction_config)
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
            bucket = output_config.get('bucket', self.config['s3_bucket'])
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
            self.s3_client.put_object(
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
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get extraction metrics"""
        end_time = datetime.now()
        processing_time = (end_time - self.metrics['start_time']).total_seconds()
        
        return {
            'records_extracted': self.metrics['records_extracted'],
            'files_processed': self.metrics['files_processed'],
            'errors': self.metrics['errors'],
            'processing_time': processing_time,
            'start_time': self.metrics['start_time'].isoformat(),
            'end_time': end_time.isoformat()
        }

# Initialize extractor
extractor = DataExtractor()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'timestamp': datetime.now().isoformat()})

@app.route('/extract', methods=['POST'])
def extract_endpoint():
    """Extract data endpoint"""
    try:
        # Get extraction configuration from request
        extraction_config = request.json.get('extraction_config', {})
        output_config = request.json.get('output_config', {})
        
        # Extract data
        df = extractor.extract_data(extraction_config)
        
        # Save extracted data
        s3_key = extractor.save_extracted_data(df, output_config)
        
        # Get metrics
        metrics = extractor.get_metrics()
        
        return jsonify({
            'status': 'success',
            'records_extracted': len(df),
            's3_key': s3_key,
            'metrics': metrics
        })
        
    except Exception as e:
        logger.error(f"Error in extract endpoint: {str(e)}")
        return jsonify({
            'status': 'error',
            'error': str(e)
        }), 500

def main():
    """Main function for container execution"""
    try:
        logger.info("Starting ETL Extract Container")
        
        # Check if running as ECS task
        if os.environ.get('ECS_CONTAINER_METADATA_URI'):
            logger.info("Running as ECS task")
            
            # Get task configuration from environment
            extraction_config = json.loads(os.environ.get('EXTRACTION_CONFIG', '{}'))
            output_config = json.loads(os.environ.get('OUTPUT_CONFIG', '{}'))
            
            if extraction_config:
                # Extract data
                df = extractor.extract_data(extraction_config)
                
                # Save extracted data
                s3_key = extractor.save_extracted_data(df, output_config)
                
                # Get metrics
                metrics = extractor.get_metrics()
                
                logger.info(f"Extraction completed: {metrics}")
                
                # Write results to file for ECS task
                with open('/tmp/extraction_results.json', 'w') as f:
                    json.dump({
                        'status': 'success',
                        'records_extracted': len(df),
                        's3_key': s3_key,
                        'metrics': metrics
                    }, f)
            else:
                logger.warning("No extraction configuration provided")
        else:
            logger.info("Running as standalone service")
            
            # Start Flask app
            app.run(host='0.0.0.0', port=8080, debug=False)
            
    except Exception as e:
        logger.error(f"Error in main: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()

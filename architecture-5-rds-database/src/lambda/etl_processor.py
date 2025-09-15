#!/usr/bin/env python3
"""
Architecture 5: RDS Database ETL - ETL Processor Lambda Function

This Lambda function processes data from source databases and loads it into target databases.
It handles database connections, data extraction, transformation, and loading operations.

Author: AWS ETL Architecture Team
Version: 1.0
"""

import json
import logging
import os
import psycopg2
import boto3
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
import pandas as pd
from sqlalchemy import create_engine, text
import aws_encryption_sdk
from aws_encryption_sdk import KMSKeyring, CommitmentPolicy

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
secrets_manager = boto3.client('secretsmanager')
s3_client = boto3.client('s3')
cloudwatch = boto3.client('cloudwatch')

class DatabaseETLProcessor:
    """
    Database ETL Processor for RDS-based ETL operations
    """
    
    def __init__(self, event: Dict[str, Any], context):
        """
        Initialize the ETL processor
        
        Args:
            event: Lambda event data
            context: Lambda context
        """
        self.event = event
        self.context = context
        self.logger = logging.getLogger(self.__class__.__name__)
        
        # Database connection parameters
        self.source_config = self._get_database_config('source')
        self.target_config = self._get_database_config('target')
        
        # S3 configuration
        self.s3_bucket = os.environ.get('S3_BUCKET')
        
        # Initialize connections
        self.source_conn = None
        self.target_conn = None
        
        # ETL metrics
        self.metrics = {
            'records_processed': 0,
            'records_failed': 0,
            'processing_time': 0,
            'start_time': datetime.now()
        }
    
    def _get_database_config(self, db_type: str) -> Dict[str, Any]:
        """
        Get database configuration from environment variables
        
        Args:
            db_type: Type of database (source or target)
            
        Returns:
            Dict: Database configuration
        """
        try:
            if db_type == 'source':
                return {
                    'host': os.environ.get('SOURCE_DB_HOST'),
                    'database': os.environ.get('SOURCE_DB_NAME'),
                    'username': os.environ.get('SOURCE_DB_USERNAME'),
                    'password_secret': os.environ.get('SOURCE_DB_PASSWORD_SECRET', 'source-db-password')
                }
            else:
                return {
                    'host': os.environ.get('TARGET_DB_HOST'),
                    'database': os.environ.get('TARGET_DB_NAME'),
                    'username': os.environ.get('TARGET_DB_USERNAME'),
                    'password_secret': os.environ.get('TARGET_DB_PASSWORD_SECRET', 'target-db-password')
                }
        except Exception as e:
            self.logger.error(f"Error getting database config for {db_type}: {str(e)}")
            raise
    
    def _get_secret(self, secret_name: str) -> str:
        """
        Retrieve secret from AWS Secrets Manager
        
        Args:
            secret_name: Name of the secret
            
        Returns:
            str: Secret value
        """
        try:
            response = secrets_manager.get_secret_value(SecretId=secret_name)
            return response['SecretString']
        except Exception as e:
            self.logger.error(f"Error retrieving secret {secret_name}: {str(e)}")
            raise
    
    def _connect_to_database(self, config: Dict[str, Any]) -> psycopg2.extensions.connection:
        """
        Connect to database using provided configuration
        
        Args:
            config: Database configuration
            
        Returns:
            psycopg2.extensions.connection: Database connection
        """
        try:
            password = self._get_secret(config['password_secret'])
            
            connection = psycopg2.connect(
                host=config['host'],
                database=config['database'],
                user=config['username'],
                password=password,
                port=5432,
                connect_timeout=30,
                application_name='etl-processor'
            )
            
            connection.autocommit = False
            self.logger.info(f"Successfully connected to database: {config['host']}")
            return connection
            
        except Exception as e:
            self.logger.error(f"Error connecting to database {config['host']}: {str(e)}")
            raise
    
    def _execute_query(self, connection: psycopg2.extensions.connection, query: str, params: Optional[Tuple] = None) -> List[Tuple]:
        """
        Execute a query and return results
        
        Args:
            connection: Database connection
            query: SQL query to execute
            params: Query parameters
            
        Returns:
            List[Tuple]: Query results
        """
        try:
            with connection.cursor() as cursor:
                cursor.execute(query, params)
                results = cursor.fetchall()
                self.logger.info(f"Query executed successfully, returned {len(results)} rows")
                return results
        except Exception as e:
            self.logger.error(f"Error executing query: {str(e)}")
            raise
    
    def _extract_data(self, extraction_config: Dict[str, Any]) -> pd.DataFrame:
        """
        Extract data from source database
        
        Args:
            extraction_config: Extraction configuration
            
        Returns:
            pd.DataFrame: Extracted data
        """
        try:
            self.logger.info("Starting data extraction")
            
            # Connect to source database
            if not self.source_conn:
                self.source_conn = self._connect_to_database(self.source_config)
            
            # Build extraction query
            query = extraction_config.get('query')
            if not query:
                # Build query from table configuration
                table_name = extraction_config['table_name']
                columns = extraction_config.get('columns', '*')
                where_clause = extraction_config.get('where_clause', '')
                order_by = extraction_config.get('order_by', '')
                
                query = f"SELECT {columns} FROM {table_name}"
                if where_clause:
                    query += f" WHERE {where_clause}"
                if order_by:
                    query += f" ORDER BY {order_by}"
            
            # Execute extraction query
            results = self._execute_query(self.source_conn, query)
            
            # Convert to DataFrame
            column_names = [desc[0] for desc in self.source_conn.cursor().description]
            df = pd.DataFrame(results, columns=column_names)
            
            self.logger.info(f"Extracted {len(df)} records from source database")
            return df
            
        except Exception as e:
            self.logger.error(f"Error in data extraction: {str(e)}")
            raise
    
    def _transform_data(self, df: pd.DataFrame, transformation_config: Dict[str, Any]) -> pd.DataFrame:
        """
        Transform extracted data
        
        Args:
            df: Input DataFrame
            transformation_config: Transformation configuration
            
        Returns:
            pd.DataFrame: Transformed data
        """
        try:
            self.logger.info("Starting data transformation")
            
            transformed_df = df.copy()
            
            # Apply column transformations
            if 'column_transformations' in transformation_config:
                for column, transformation in transformation_config['column_transformations'].items():
                    if column in transformed_df.columns:
                        if transformation['type'] == 'uppercase':
                            transformed_df[column] = transformed_df[column].str.upper()
                        elif transformation['type'] == 'lowercase':
                            transformed_df[column] = transformed_df[column].str.lower()
                        elif transformation['type'] == 'trim':
                            transformed_df[column] = transformed_df[column].str.strip()
                        elif transformation['type'] == 'replace':
                            transformed_df[column] = transformed_df[column].str.replace(
                                transformation['old_value'], 
                                transformation['new_value']
                            )
                        elif transformation['type'] == 'format_date':
                            transformed_df[column] = pd.to_datetime(transformed_df[column]).dt.strftime(
                                transformation['format']
                            )
                        elif transformation['type'] == 'cast':
                            if transformation['target_type'] == 'int':
                                transformed_df[column] = pd.to_numeric(transformed_df[column], errors='coerce').astype('Int64')
                            elif transformation['target_type'] == 'float':
                                transformed_df[column] = pd.to_numeric(transformed_df[column], errors='coerce')
                            elif transformation['target_type'] == 'str':
                                transformed_df[column] = transformed_df[column].astype(str)
            
            # Apply data validation
            if 'validation_rules' in transformation_config:
                transformed_df = self._validate_data(transformed_df, transformation_config['validation_rules'])
            
            # Apply data cleansing
            if 'cleansing_rules' in transformation_config:
                transformed_df = self._cleanse_data(transformed_df, transformation_config['cleansing_rules'])
            
            # Add metadata columns
            transformed_df['etl_processed_at'] = datetime.now()
            transformed_df['etl_batch_id'] = self.event.get('batch_id', f"batch_{datetime.now().strftime('%Y%m%d_%H%M%S')}")
            
            self.logger.info(f"Transformed {len(transformed_df)} records")
            return transformed_df
            
        except Exception as e:
            self.logger.error(f"Error in data transformation: {str(e)}")
            raise
    
    def _validate_data(self, df: pd.DataFrame, validation_rules: List[Dict[str, Any]]) -> pd.DataFrame:
        """
        Validate data according to rules
        
        Args:
            df: Input DataFrame
            validation_rules: List of validation rules
            
        Returns:
            pd.DataFrame: Validated DataFrame
        """
        try:
            validated_df = df.copy()
            
            for rule in validation_rules:
                column = rule['column']
                rule_type = rule['type']
                
                if column not in validated_df.columns:
                    continue
                
                if rule_type == 'not_null':
                    # Remove rows where column is null
                    before_count = len(validated_df)
                    validated_df = validated_df.dropna(subset=[column])
                    after_count = len(validated_df)
                    if before_count != after_count:
                        self.logger.warning(f"Removed {before_count - after_count} rows with null values in {column}")
                
                elif rule_type == 'unique':
                    # Remove duplicate rows based on column
                    before_count = len(validated_df)
                    validated_df = validated_df.drop_duplicates(subset=[column])
                    after_count = len(validated_df)
                    if before_count != after_count:
                        self.logger.warning(f"Removed {before_count - after_count} duplicate rows in {column}")
                
                elif rule_type == 'range':
                    # Filter rows within range
                    min_value = rule.get('min_value')
                    max_value = rule.get('max_value')
                    if min_value is not None:
                        validated_df = validated_df[validated_df[column] >= min_value]
                    if max_value is not None:
                        validated_df = validated_df[validated_df[column] <= max_value]
                
                elif rule_type == 'pattern':
                    # Filter rows matching pattern
                    pattern = rule['pattern']
                    validated_df = validated_df[validated_df[column].str.match(pattern, na=False)]
            
            return validated_df
            
        except Exception as e:
            self.logger.error(f"Error in data validation: {str(e)}")
            raise
    
    def _cleanse_data(self, df: pd.DataFrame, cleansing_rules: List[Dict[str, Any]]) -> pd.DataFrame:
        """
        Cleanse data according to rules
        
        Args:
            df: Input DataFrame
            cleansing_rules: List of cleansing rules
            
        Returns:
            pd.DataFrame: Cleaned DataFrame
        """
        try:
            cleansed_df = df.copy()
            
            for rule in cleansing_rules:
                column = rule['column']
                rule_type = rule['type']
                
                if column not in cleansed_df.columns:
                    continue
                
                if rule_type == 'remove_special_chars':
                    # Remove special characters
                    cleansed_df[column] = cleansed_df[column].str.replace(r'[^a-zA-Z0-9\s]', '', regex=True)
                
                elif rule_type == 'normalize_whitespace':
                    # Normalize whitespace
                    cleansed_df[column] = cleansed_df[column].str.replace(r'\s+', ' ', regex=True).str.strip()
                
                elif rule_type == 'fill_missing':
                    # Fill missing values
                    fill_value = rule.get('fill_value', '')
                    cleansed_df[column] = cleansed_df[column].fillna(fill_value)
                
                elif rule_type == 'remove_outliers':
                    # Remove outliers using IQR method
                    Q1 = cleansed_df[column].quantile(0.25)
                    Q3 = cleansed_df[column].quantile(0.75)
                    IQR = Q3 - Q1
                    lower_bound = Q1 - 1.5 * IQR
                    upper_bound = Q3 + 1.5 * IQR
                    cleansed_df = cleansed_df[
                        (cleansed_df[column] >= lower_bound) & 
                        (cleansed_df[column] <= upper_bound)
                    ]
            
            return cleansed_df
            
        except Exception as e:
            self.logger.error(f"Error in data cleansing: {str(e)}")
            raise
    
    def _load_data(self, df: pd.DataFrame, loading_config: Dict[str, Any]) -> bool:
        """
        Load transformed data to target database
        
        Args:
            df: Transformed DataFrame
            loading_config: Loading configuration
            
        Returns:
            bool: Success status
        """
        try:
            self.logger.info("Starting data loading")
            
            # Connect to target database
            if not self.target_conn:
                self.target_conn = self._connect_to_database(self.target_config)
            
            table_name = loading_config['table_name']
            load_mode = loading_config.get('mode', 'append')
            
            # Prepare data for insertion
            columns = list(df.columns)
            placeholders = ', '.join(['%s'] * len(columns))
            insert_query = f"INSERT INTO {table_name} ({', '.join(columns)}) VALUES ({placeholders})"
            
            # Handle different load modes
            if load_mode == 'truncate':
                # Truncate table before loading
                with self.target_conn.cursor() as cursor:
                    cursor.execute(f"TRUNCATE TABLE {table_name}")
                    self.logger.info(f"Truncated table {table_name}")
            
            elif load_mode == 'upsert':
                # Use UPSERT (INSERT ... ON CONFLICT)
                conflict_columns = loading_config.get('conflict_columns', [])
                if conflict_columns:
                    update_columns = [col for col in columns if col not in conflict_columns]
                    update_clause = ', '.join([f"{col} = EXCLUDED.{col}" for col in update_columns])
                    insert_query += f" ON CONFLICT ({', '.join(conflict_columns)}) DO UPDATE SET {update_clause}"
            
            # Insert data in batches
            batch_size = loading_config.get('batch_size', 1000)
            total_rows = len(df)
            successful_rows = 0
            
            for i in range(0, total_rows, batch_size):
                batch_df = df.iloc[i:i + batch_size]
                batch_data = [tuple(row) for row in batch_df.values]
                
                try:
                    with self.target_conn.cursor() as cursor:
                        cursor.executemany(insert_query, batch_data)
                        self.target_conn.commit()
                        successful_rows += len(batch_data)
                        self.logger.info(f"Loaded batch {i//batch_size + 1}: {len(batch_data)} rows")
                
                except Exception as e:
                    self.logger.error(f"Error loading batch {i//batch_size + 1}: {str(e)}")
                    self.target_conn.rollback()
                    self.metrics['records_failed'] += len(batch_data)
                    continue
            
            self.metrics['records_processed'] = successful_rows
            self.logger.info(f"Successfully loaded {successful_rows} out of {total_rows} rows")
            
            return successful_rows > 0
            
        except Exception as e:
            self.logger.error(f"Error in data loading: {str(e)}")
            if self.target_conn:
                self.target_conn.rollback()
            raise
    
    def _save_to_s3(self, df: pd.DataFrame, s3_config: Dict[str, Any]) -> str:
        """
        Save DataFrame to S3
        
        Args:
            df: DataFrame to save
            s3_config: S3 configuration
            
        Returns:
            str: S3 object key
        """
        try:
            bucket = s3_config.get('bucket', self.s3_bucket)
            key = s3_config.get('key', f"etl-data/{datetime.now().strftime('%Y/%m/%d')}/data_{datetime.now().strftime('%Y%m%d_%H%M%S')}.parquet")
            format_type = s3_config.get('format', 'parquet')
            
            # Convert DataFrame to bytes
            if format_type == 'parquet':
                buffer = df.to_parquet(index=False)
            elif format_type == 'csv':
                buffer = df.to_csv(index=False).encode('utf-8')
            elif format_type == 'json':
                buffer = df.to_json(orient='records').encode('utf-8')
            else:
                raise ValueError(f"Unsupported format: {format_type}")
            
            # Upload to S3
            s3_client.put_object(
                Bucket=bucket,
                Key=key,
                Body=buffer,
                ContentType='application/octet-stream'
            )
            
            self.logger.info(f"Saved data to S3: s3://{bucket}/{key}")
            return key
            
        except Exception as e:
            self.logger.error(f"Error saving to S3: {str(e)}")
            raise
    
    def _send_metrics(self):
        """
        Send custom metrics to CloudWatch
        """
        try:
            end_time = datetime.now()
            self.metrics['processing_time'] = (end_time - self.metrics['start_time']).total_seconds()
            
            # Send custom metrics
            cloudwatch.put_metric_data(
                Namespace='ETL/Database',
                MetricData=[
                    {
                        'MetricName': 'RecordsProcessed',
                        'Value': self.metrics['records_processed'],
                        'Unit': 'Count',
                        'Dimensions': [
                            {
                                'Name': 'FunctionName',
                                'Value': self.context.function_name
                            }
                        ]
                    },
                    {
                        'MetricName': 'RecordsFailed',
                        'Value': self.metrics['records_failed'],
                        'Unit': 'Count',
                        'Dimensions': [
                            {
                                'Name': 'FunctionName',
                                'Value': self.context.function_name
                            }
                        ]
                    },
                    {
                        'MetricName': 'ProcessingTime',
                        'Value': self.metrics['processing_time'],
                        'Unit': 'Seconds',
                        'Dimensions': [
                            {
                                'Name': 'FunctionName',
                                'Value': self.context.function_name
                            }
                        ]
                    }
                ]
            )
            
            self.logger.info("Metrics sent to CloudWatch successfully")
            
        except Exception as e:
            self.logger.error(f"Error sending metrics: {str(e)}")
    
    def process_etl_job(self) -> Dict[str, Any]:
        """
        Process the complete ETL job
        
        Returns:
            Dict: Processing results
        """
        try:
            self.logger.info("Starting ETL job processing")
            
            # Get ETL configuration from event
            etl_config = self.event.get('etl_config', {})
            
            # Extract data
            extraction_config = etl_config.get('extraction', {})
            if not extraction_config:
                raise ValueError("Extraction configuration is required")
            
            df = self._extract_data(extraction_config)
            
            # Transform data
            transformation_config = etl_config.get('transformation', {})
            if transformation_config:
                df = self._transform_data(df, transformation_config)
            
            # Load data
            loading_config = etl_config.get('loading', {})
            if loading_config:
                success = self._load_data(df, loading_config)
                if not success:
                    raise Exception("Data loading failed")
            
            # Save to S3 (optional)
            s3_config = etl_config.get('s3_backup', {})
            if s3_config:
                s3_key = self._save_to_s3(df, s3_config)
                self.metrics['s3_backup_key'] = s3_key
            
            # Send metrics
            self._send_metrics()
            
            result = {
                'status': 'success',
                'records_processed': self.metrics['records_processed'],
                'records_failed': self.metrics['records_failed'],
                'processing_time': self.metrics['processing_time'],
                'timestamp': datetime.now().isoformat()
            }
            
            if 's3_backup_key' in self.metrics:
                result['s3_backup_key'] = self.metrics['s3_backup_key']
            
            self.logger.info(f"ETL job completed successfully: {result}")
            return result
            
        except Exception as e:
            self.logger.error(f"ETL job failed: {str(e)}")
            self._send_metrics()
            raise
        finally:
            # Close database connections
            if self.source_conn:
                self.source_conn.close()
            if self.target_conn:
                self.target_conn.close()


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
        
        # Initialize ETL processor
        processor = DatabaseETLProcessor(event, context)
        
        # Process ETL job
        result = processor.process_etl_job()
        
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

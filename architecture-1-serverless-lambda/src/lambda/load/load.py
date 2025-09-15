"""
Load Lambda Function for Serverless ETL Architecture
Loads transformed data from S3 into Redshift data warehouse
"""

import json
import os
import boto3
import psycopg2
from datetime import datetime
from typing import Dict, List, Any, Optional
import logging
import pandas as pd
from io import StringIO

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3 = boto3.client('s3')
redshift = boto3.client('redshift')

def lambda_handler(event, context):
    """
    Main Lambda handler for data loading
    """
    try:
        logger.info(f"Starting load process. Event: {event}")
        
        # Get environment variables
        target_redshift_endpoint = os.environ['TARGET_REDSHIFT_ENDPOINT']
        staging_bucket_name = os.environ['STAGING_BUCKET_NAME']
        
        # Process the event (could be from S3 trigger or direct invocation)
        if 'Records' in event:
            # S3 trigger event
            for record in event['Records']:
                bucket = record['s3']['bucket']['name']
                key = record['s3']['object']['key']
                
                if key.startswith('transformed/'):
                    load_data_to_redshift(bucket, key, target_redshift_endpoint)
        else:
            # Direct invocation with data location
            data_location = event.get('data_location', {})
            bucket = data_location.get('bucket', staging_bucket_name)
            key = data_location.get('key')
            
            if key:
                load_data_to_redshift(bucket, key, target_redshift_endpoint)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Data loading completed successfully',
                'timestamp': datetime.now().isoformat()
            })
        }
        
    except Exception as e:
        logger.error(f"Error in load process: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': 'Data loading failed'
            })
        }

def load_data_to_redshift(bucket: str, key: str, redshift_endpoint: str):
    """
    Load data from S3 to Redshift
    """
    try:
        # Download transformed data from S3
        response = s3.get_object(Bucket=bucket, Key=key)
        transformed_data = json.loads(response['Body'].read().decode('utf-8'))
        
        logger.info(f"Downloaded transformed data from S3: {bucket}/{key}")
        
        # Parse endpoint to get host and port
        host = redshift_endpoint.split(':')[0]
        port = int(redshift_endpoint.split(':')[1]) if ':' in redshift_endpoint else 5439
        
        # Connect to Redshift
        connection = psycopg2.connect(
            host=host,
            port=port,
            database='etl_warehouse',
            user='etl_user',
            password=os.environ.get('REDSHIFT_PASSWORD', 'default_password')
        )
        
        connection.autocommit = False
        cursor = connection.cursor()
        
        # Create tables if they don't exist
        create_tables_if_not_exist(cursor)
        
        # Load data based on record type
        records = transformed_data.get('transformed_records', [])
        load_summary = {
            'total_records': len(records),
            'loaded_by_type': {},
            'errors': []
        }
        
        # Group records by type
        records_by_type = {}
        for record in records:
            record_type = record.get('record_type', 'unknown')
            if record_type not in records_by_type:
                records_by_type[record_type] = []
            records_by_type[record_type].append(record)
        
        # Load each record type
        for record_type, type_records in records_by_type.items():
            try:
                if record_type == 'order':
                    loaded_count = load_orders(cursor, type_records)
                elif record_type == 'product':
                    loaded_count = load_products(cursor, type_records)
                else:
                    logger.warning(f"Unknown record type: {record_type}")
                    continue
                
                load_summary['loaded_by_type'][record_type] = loaded_count
                logger.info(f"Loaded {loaded_count} {record_type} records")
                
            except Exception as e:
                error_msg = f"Error loading {record_type} records: {str(e)}"
                logger.error(error_msg)
                load_summary['errors'].append(error_msg)
        
        # Commit transaction
        connection.commit()
        cursor.close()
        connection.close()
        
        # Store load summary in S3
        summary_key = f"load_summaries/{datetime.now().strftime('%Y/%m/%d/%H')}/load_summary_{context.aws_request_id}.json"
        s3.put_object(
            Bucket=bucket,
            Key=summary_key,
            Body=json.dumps(load_summary, default=str),
            ContentType='application/json'
        )
        
        logger.info(f"Load process completed. Summary: {load_summary}")
        
    except Exception as e:
        logger.error(f"Error loading data to Redshift: {str(e)}")
        raise

def create_tables_if_not_exist(cursor):
    """
    Create tables in Redshift if they don't exist
    """
    try:
        # Create orders table
        orders_table_sql = """
        CREATE TABLE IF NOT EXISTS orders (
            record_id VARCHAR(50) PRIMARY KEY,
            customer_id INTEGER,
            order_date TIMESTAMP,
            total_amount DECIMAL(10,2),
            status VARCHAR(20),
            created_at TIMESTAMP,
            updated_at TIMESTAMP,
            transformation_timestamp TIMESTAMP,
            amount_category VARCHAR(10),
            is_recent BOOLEAN,
            priority_score INTEGER,
            load_timestamp TIMESTAMP DEFAULT GETDATE()
        )
        DISTKEY(customer_id)
        SORTKEY(order_date, created_at);
        """
        
        cursor.execute(orders_table_sql)
        
        # Create products table
        products_table_sql = """
        CREATE TABLE IF NOT EXISTS products (
            record_id VARCHAR(50) PRIMARY KEY,
            name VARCHAR(255),
            price DECIMAL(10,2),
            category VARCHAR(100),
            api_source VARCHAR(100),
            source_timestamp TIMESTAMP,
            transformation_timestamp TIMESTAMP,
            price_category VARCHAR(20),
            is_premium BOOLEAN,
            load_timestamp TIMESTAMP DEFAULT GETDATE()
        )
        DISTKEY(category)
        SORTKEY(category, price);
        """
        
        cursor.execute(products_table_sql)
        
        # Create load_log table for tracking
        load_log_sql = """
        CREATE TABLE IF NOT EXISTS load_log (
            load_id VARCHAR(50) PRIMARY KEY,
            source_file VARCHAR(500),
            load_timestamp TIMESTAMP,
            total_records INTEGER,
            successful_records INTEGER,
            failed_records INTEGER,
            load_duration_seconds INTEGER,
            status VARCHAR(20)
        )
        DISTSTYLE ALL
        SORTKEY(load_timestamp);
        """
        
        cursor.execute(load_log_sql)
        
        logger.info("Tables created/verified successfully")
        
    except Exception as e:
        logger.error(f"Error creating tables: {str(e)}")
        raise

def load_orders(cursor, orders: List[Dict[str, Any]]) -> int:
    """
    Load order records to Redshift
    """
    loaded_count = 0
    
    for order in orders:
        try:
            insert_sql = """
            INSERT INTO orders (
                record_id, customer_id, order_date, total_amount, status,
                created_at, updated_at, transformation_timestamp,
                amount_category, is_recent, priority_score
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
            ON CONFLICT (record_id) DO UPDATE SET
                customer_id = EXCLUDED.customer_id,
                order_date = EXCLUDED.order_date,
                total_amount = EXCLUDED.total_amount,
                status = EXCLUDED.status,
                updated_at = EXCLUDED.updated_at,
                transformation_timestamp = EXCLUDED.transformation_timestamp,
                amount_category = EXCLUDED.amount_category,
                is_recent = EXCLUDED.is_recent,
                priority_score = EXCLUDED.priority_score,
                load_timestamp = GETDATE()
            """
            
            cursor.execute(insert_sql, (
                order.get('record_id'),
                order.get('customer_id'),
                order.get('order_date'),
                order.get('total_amount'),
                order.get('status'),
                order.get('created_at'),
                order.get('updated_at'),
                order.get('transformation_timestamp'),
                order.get('amount_category'),
                order.get('is_recent'),
                order.get('priority_score')
            ))
            
            loaded_count += 1
            
        except Exception as e:
            logger.error(f"Error loading order {order.get('record_id')}: {str(e)}")
            continue
    
    return loaded_count

def load_products(cursor, products: List[Dict[str, Any]]) -> int:
    """
    Load product records to Redshift
    """
    loaded_count = 0
    
    for product in products:
        try:
            insert_sql = """
            INSERT INTO products (
                record_id, name, price, category, api_source,
                source_timestamp, transformation_timestamp,
                price_category, is_premium
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
            ON CONFLICT (record_id) DO UPDATE SET
                name = EXCLUDED.name,
                price = EXCLUDED.price,
                category = EXCLUDED.category,
                api_source = EXCLUDED.api_source,
                source_timestamp = EXCLUDED.source_timestamp,
                transformation_timestamp = EXCLUDED.transformation_timestamp,
                price_category = EXCLUDED.price_category,
                is_premium = EXCLUDED.is_premium,
                load_timestamp = GETDATE()
            """
            
            cursor.execute(insert_sql, (
                product.get('record_id'),
                product.get('name'),
                product.get('price'),
                product.get('category'),
                product.get('api_source'),
                product.get('source_timestamp'),
                product.get('transformation_timestamp'),
                product.get('price_category'),
                product.get('is_premium')
            ))
            
            loaded_count += 1
            
        except Exception as e:
            logger.error(f"Error loading product {product.get('record_id')}: {str(e)}")
            continue
    
    return loaded_count

def log_load_activity(cursor, load_id: str, source_file: str, 
                     total_records: int, successful_records: int, 
                     failed_records: int, duration_seconds: int, status: str):
    """
    Log load activity to load_log table
    """
    try:
        insert_sql = """
        INSERT INTO load_log (
            load_id, source_file, load_timestamp, total_records,
            successful_records, failed_records, load_duration_seconds, status
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s, %s
        )
        """
        
        cursor.execute(insert_sql, (
            load_id,
            source_file,
            datetime.now(),
            total_records,
            successful_records,
            failed_records,
            duration_seconds,
            status
        ))
        
    except Exception as e:
        logger.error(f"Error logging load activity: {str(e)}")

def validate_redshift_connection(endpoint: str) -> bool:
    """
    Validate Redshift connection
    """
    try:
        host = endpoint.split(':')[0]
        port = int(endpoint.split(':')[1]) if ':' in endpoint else 5439
        
        connection = psycopg2.connect(
            host=host,
            port=port,
            database='etl_warehouse',
            user='etl_user',
            password=os.environ.get('REDSHIFT_PASSWORD', 'default_password'),
            connect_timeout=10
        )
        
        cursor = connection.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        connection.close()
        
        return True
        
    except Exception as e:
        logger.error(f"Redshift connection validation failed: {str(e)}")
        return False

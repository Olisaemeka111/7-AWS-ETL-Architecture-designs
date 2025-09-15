"""
AWS Glue ETL Job - Extract Data from Multiple Sources
This job extracts data from various sources and stores it in the raw zone of the data lake.
"""

import sys
import boto3
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import DataFrame
from pyspark.sql.functions import *
from pyspark.sql.types import *
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

# Get job parameters
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'RAW_ZONE_BUCKET',
    'CLEAN_ZONE_BUCKET',
    'TEMP_ZONE_BUCKET'
])

job.init(args['JOB_NAME'], args)

# Configuration
RAW_ZONE_BUCKET = args['RAW_ZONE_BUCKET']
CLEAN_ZONE_BUCKET = args['CLEAN_ZONE_BUCKET']
TEMP_ZONE_BUCKET = args['TEMP_ZONE_BUCKET']

# Data sources configuration
DATA_SOURCES = {
    'legislators': {
        'source_path': 's3://aws-glue-datasets/examples/us-legislators/all/',
        'format': 'json',
        'table_name': 'legislators_raw'
    },
    'sample_sales': {
        'source_path': 's3://aws-glue-datasets/examples/us-legislators/all/',
        'format': 'json',
        'table_name': 'sales_raw'
    }
}

def extract_from_s3(source_config, source_name):
    """
    Extract data from S3 source
    """
    try:
        logger.info(f"Extracting data from {source_name}: {source_config['source_path']}")
        
        # Read data based on format
        if source_config['format'] == 'json':
            df = spark.read.json(source_config['source_path'])
        elif source_config['format'] == 'csv':
            df = spark.read.option("header", "true").csv(source_config['source_path'])
        elif source_config['format'] == 'parquet':
            df = spark.read.parquet(source_config['source_path'])
        else:
            raise ValueError(f"Unsupported format: {source_config['format']}")
        
        # Add metadata columns
        df = df.withColumn("extract_timestamp", current_timestamp()) \
               .withColumn("source_name", lit(source_name)) \
               .withColumn("extract_date", current_date())
        
        # Show schema and count
        logger.info(f"Schema for {source_name}:")
        df.printSchema()
        logger.info(f"Record count for {source_name}: {df.count()}")
        
        return df
        
    except Exception as e:
        logger.error(f"Error extracting data from {source_name}: {str(e)}")
        raise

def extract_from_database(connection_name, table_name, source_name):
    """
    Extract data from database connection
    """
    try:
        logger.info(f"Extracting data from database: {connection_name}.{table_name}")
        
        # Create dynamic frame from database
        dynamic_frame = glueContext.create_dynamic_frame.from_options(
            connection_type="mysql",
            connection_options={
                "useConnectionProperties": "true",
                "connectionName": connection_name,
                "dbtable": table_name
            }
        )
        
        # Convert to DataFrame
        df = dynamic_frame.toDF()
        
        # Add metadata columns
        df = df.withColumn("extract_timestamp", current_timestamp()) \
               .withColumn("source_name", lit(source_name)) \
               .withColumn("extract_date", current_date())
        
        logger.info(f"Record count for {source_name}: {df.count()}")
        
        return df
        
    except Exception as e:
        logger.error(f"Error extracting data from database {source_name}: {str(e)}")
        raise

def validate_data(df, source_name):
    """
    Validate extracted data
    """
    try:
        logger.info(f"Validating data for {source_name}")
        
        # Check if DataFrame is empty
        if df.count() == 0:
            logger.warning(f"No data found for {source_name}")
            return False
        
        # Check for null values in key columns
        null_counts = {}
        for column in df.columns:
            null_count = df.filter(col(column).isNull()).count()
            if null_count > 0:
                null_counts[column] = null_count
        
        if null_counts:
            logger.warning(f"Null values found in {source_name}: {null_counts}")
        
        # Log data quality metrics
        total_records = df.count()
        logger.info(f"Data quality metrics for {source_name}:")
        logger.info(f"  Total records: {total_records}")
        logger.info(f"  Columns: {len(df.columns)}")
        logger.info(f"  Null value columns: {len(null_counts)}")
        
        return True
        
    except Exception as e:
        logger.error(f"Error validating data for {source_name}: {str(e)}")
        return False

def save_to_raw_zone(df, source_name, table_name):
    """
    Save extracted data to raw zone
    """
    try:
        logger.info(f"Saving {source_name} to raw zone")
        
        # Define output path
        output_path = f"s3://{RAW_ZONE_BUCKET}/sources/{source_name}/"
        
        # Partition by extract date for better organization
        df.write \
          .mode("overwrite") \
          .partitionBy("extract_date") \
          .parquet(output_path)
        
        logger.info(f"Successfully saved {source_name} to {output_path}")
        
        # Also save as a Glue table for cataloging
        df.write \
          .mode("overwrite") \
          .option("path", output_path) \
          .saveAsTable(f"raw_{table_name}")
        
        return True
        
    except Exception as e:
        logger.error(f"Error saving {source_name} to raw zone: {str(e)}")
        raise

def main():
    """
    Main extraction logic
    """
    try:
        logger.info("Starting data extraction job")
        
        # Track extraction results
        extraction_results = {}
        
        # Extract from S3 sources
        for source_name, source_config in DATA_SOURCES.items():
            try:
                logger.info(f"Processing S3 source: {source_name}")
                
                # Extract data
                df = extract_from_s3(source_config, source_name)
                
                # Validate data
                if validate_data(df, source_name):
                    # Save to raw zone
                    save_to_raw_zone(df, source_name, source_config['table_name'])
                    extraction_results[source_name] = {
                        'status': 'success',
                        'record_count': df.count(),
                        'columns': len(df.columns)
                    }
                else:
                    extraction_results[source_name] = {
                        'status': 'failed',
                        'reason': 'validation_failed'
                    }
                    
            except Exception as e:
                logger.error(f"Failed to process source {source_name}: {str(e)}")
                extraction_results[source_name] = {
                    'status': 'failed',
                    'reason': str(e)
                }
        
        # Log final results
        logger.info("Extraction job completed")
        logger.info(f"Results: {extraction_results}")
        
        # Send custom metrics to CloudWatch
        try:
            cloudwatch = boto3.client('cloudwatch')
            
            for source_name, result in extraction_results.items():
                if result['status'] == 'success':
                    cloudwatch.put_metric_data(
                        Namespace='ETL/Extract',
                        MetricData=[
                            {
                                'MetricName': 'RecordsExtracted',
                                'Value': result['record_count'],
                                'Unit': 'Count',
                                'Dimensions': [
                                    {
                                        'Name': 'Source',
                                        'Value': source_name
                                    }
                                ]
                            }
                        ]
                    )
        except Exception as e:
            logger.warning(f"Failed to send metrics to CloudWatch: {str(e)}")
        
        return extraction_results
        
    except Exception as e:
        logger.error(f"Extraction job failed: {str(e)}")
        raise

# Execute main function
if __name__ == "__main__":
    try:
        results = main()
        job.commit()
        logger.info("Job completed successfully")
    except Exception as e:
        logger.error(f"Job failed: {str(e)}")
        raise

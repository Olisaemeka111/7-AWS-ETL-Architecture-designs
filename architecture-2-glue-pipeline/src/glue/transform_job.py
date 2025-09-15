"""
AWS Glue ETL Job - Transform Data
This job transforms raw data from the raw zone and stores it in the clean zone.
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
from datetime import datetime

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

def read_raw_data(source_name):
    """
    Read raw data from S3
    """
    try:
        logger.info(f"Reading raw data for {source_name}")
        
        # Read from raw zone
        raw_path = f"s3://{RAW_ZONE_BUCKET}/sources/{source_name}/"
        df = spark.read.parquet(raw_path)
        
        logger.info(f"Loaded {df.count()} records for {source_name}")
        return df
        
    except Exception as e:
        logger.error(f"Error reading raw data for {source_name}: {str(e)}")
        raise

def clean_legislators_data(df):
    """
    Clean and transform legislators data
    """
    try:
        logger.info("Transforming legislators data")
        
        # Select and rename columns
        cleaned_df = df.select(
            col("id").alias("legislator_id"),
            col("name").alias("full_name"),
            col("first_name"),
            col("last_name"),
            col("gender"),
            col("type"),
            col("state"),
            col("party"),
            col("url"),
            col("contact_form"),
            col("rss_url"),
            col("twitter"),
            col("facebook"),
            col("youtube"),
            col("instagram"),
            col("bioguide_id"),
            col("thomas_id"),
            col("opensecrets_id"),
            col("votesmart_id"),
            col("fec_id"),
            col("cspan_id"),
            col("govtrack_id"),
            col("ballotpedia_id"),
            col("wikipedia_id"),
            col("house_history_id"),
            col("maplight_id"),
            col("icpsr_id"),
            col("wikidata_id"),
            col("google_entity_id"),
            col("in_office").alias("currently_in_office"),
            col("extract_timestamp"),
            col("source_name"),
            col("extract_date")
        )
        
        # Data quality transformations
        cleaned_df = cleaned_df.withColumn(
            "full_name", 
            when(col("full_name").isNull(), 
                 concat_ws(" ", col("first_name"), col("last_name")))
            .otherwise(col("full_name"))
        )
        
        # Standardize gender values
        cleaned_df = cleaned_df.withColumn(
            "gender",
            when(col("gender").isin(["M", "Male"]), "Male")
            .when(col("gender").isin(["F", "Female"]), "Female")
            .otherwise("Unknown")
        )
        
        # Standardize party values
        cleaned_df = cleaned_df.withColumn(
            "party",
            when(col("party").isNull(), "Unknown")
            .otherwise(col("party"))
        )
        
        # Add data quality flags
        cleaned_df = cleaned_df.withColumn(
            "data_quality_score",
            when(col("full_name").isNotNull() & col("state").isNotNull() & col("party").isNotNull(), 100)
            .when(col("full_name").isNotNull() & col("state").isNotNull(), 80)
            .when(col("full_name").isNotNull(), 60)
            .otherwise(40)
        )
        
        # Add transformation timestamp
        cleaned_df = cleaned_df.withColumn("transform_timestamp", current_timestamp())
        
        logger.info(f"Transformed legislators data: {cleaned_df.count()} records")
        return cleaned_df
        
    except Exception as e:
        logger.error(f"Error transforming legislators data: {str(e)}")
        raise

def clean_sales_data(df):
    """
    Clean and transform sales data (placeholder for sample data)
    """
    try:
        logger.info("Transforming sales data")
        
        # Since we're using legislators data as sample, we'll create a mock sales transformation
        # In a real scenario, this would be actual sales data transformation
        
        # Create mock sales data from legislators data
        sales_df = df.select(
            col("id").alias("sale_id"),
            col("name").alias("customer_name"),
            col("state").alias("region"),
            col("party").alias("customer_segment"),
            col("extract_timestamp"),
            col("source_name"),
            col("extract_date")
        )
        
        # Add mock sales fields
        sales_df = sales_df.withColumn(
            "sale_amount",
            (rand() * 1000 + 100).cast("decimal(10,2)")
        )
        
        sales_df = sales_df.withColumn(
            "sale_date",
            date_sub(current_date(), (rand() * 365).cast("int"))
        )
        
        sales_df = sales_df.withColumn(
            "product_category",
            when(col("customer_segment") == "Republican", "Electronics")
            .when(col("customer_segment") == "Democrat", "Books")
            .otherwise("General")
        )
        
        # Add transformation timestamp
        sales_df = sales_df.withColumn("transform_timestamp", current_timestamp())
        
        logger.info(f"Transformed sales data: {sales_df.count()} records")
        return sales_df
        
    except Exception as e:
        logger.error(f"Error transforming sales data: {str(e)}")
        raise

def validate_transformed_data(df, source_name):
    """
    Validate transformed data
    """
    try:
        logger.info(f"Validating transformed data for {source_name}")
        
        # Check record count
        record_count = df.count()
        if record_count == 0:
            logger.warning(f"No records found in transformed data for {source_name}")
            return False
        
        # Check for required columns
        required_columns = ["transform_timestamp", "source_name"]
        missing_columns = [col for col in required_columns if col not in df.columns]
        
        if missing_columns:
            logger.error(f"Missing required columns in {source_name}: {missing_columns}")
            return False
        
        # Check data quality
        null_counts = {}
        for column in df.columns:
            null_count = df.filter(col(column).isNull()).count()
            if null_count > 0:
                null_counts[column] = null_count
        
        # Log validation results
        logger.info(f"Validation results for {source_name}:")
        logger.info(f"  Total records: {record_count}")
        logger.info(f"  Columns: {len(df.columns)}")
        logger.info(f"  Columns with nulls: {len(null_counts)}")
        
        if null_counts:
            logger.warning(f"Null values found: {null_counts}")
        
        return True
        
    except Exception as e:
        logger.error(f"Error validating transformed data for {source_name}: {str(e)}")
        return False

def save_to_clean_zone(df, source_name, table_name):
    """
    Save transformed data to clean zone
    """
    try:
        logger.info(f"Saving transformed {source_name} to clean zone")
        
        # Define output path
        output_path = f"s3://{CLEAN_ZONE_BUCKET}/tables/{table_name}/"
        
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
          .saveAsTable(f"clean_{table_name}")
        
        return True
        
    except Exception as e:
        logger.error(f"Error saving {source_name} to clean zone: {str(e)}")
        raise

def create_data_quality_report(df, source_name):
    """
    Create data quality report
    """
    try:
        logger.info(f"Creating data quality report for {source_name}")
        
        # Calculate quality metrics
        total_records = df.count()
        total_columns = len(df.columns)
        
        # Count null values per column
        null_metrics = {}
        for column in df.columns:
            null_count = df.filter(col(column).isNull()).count()
            null_percentage = (null_count / total_records) * 100 if total_records > 0 else 0
            null_metrics[column] = {
                'null_count': null_count,
                'null_percentage': null_percentage
            }
        
        # Create quality report DataFrame
        quality_report = spark.createDataFrame([
            {
                'source_name': source_name,
                'total_records': total_records,
                'total_columns': total_columns,
                'quality_timestamp': datetime.now(),
                'null_metrics': str(null_metrics)
            }
        ])
        
        # Save quality report
        quality_path = f"s3://{CLEAN_ZONE_BUCKET}/quality_reports/{source_name}/"
        quality_report.write \
          .mode("append") \
          .parquet(quality_path)
        
        logger.info(f"Data quality report saved for {source_name}")
        
    except Exception as e:
        logger.error(f"Error creating data quality report for {source_name}: {str(e)}")

def main():
    """
    Main transformation logic
    """
    try:
        logger.info("Starting data transformation job")
        
        # Define transformation rules
        transformation_rules = {
            'legislators': clean_legislators_data,
            'sample_sales': clean_sales_data
        }
        
        # Track transformation results
        transformation_results = {}
        
        # Process each source
        for source_name, transform_function in transformation_rules.items():
            try:
                logger.info(f"Processing transformation for {source_name}")
                
                # Read raw data
                raw_df = read_raw_data(source_name)
                
                # Apply transformation
                transformed_df = transform_function(raw_df)
                
                # Validate transformed data
                if validate_transformed_data(transformed_df, source_name):
                    # Save to clean zone
                    table_name = f"{source_name}_clean"
                    save_to_clean_zone(transformed_df, source_name, table_name)
                    
                    # Create data quality report
                    create_data_quality_report(transformed_df, source_name)
                    
                    transformation_results[source_name] = {
                        'status': 'success',
                        'record_count': transformed_df.count(),
                        'columns': len(transformed_df.columns)
                    }
                else:
                    transformation_results[source_name] = {
                        'status': 'failed',
                        'reason': 'validation_failed'
                    }
                    
            except Exception as e:
                logger.error(f"Failed to transform {source_name}: {str(e)}")
                transformation_results[source_name] = {
                    'status': 'failed',
                    'reason': str(e)
                }
        
        # Log final results
        logger.info("Transformation job completed")
        logger.info(f"Results: {transformation_results}")
        
        # Send custom metrics to CloudWatch
        try:
            cloudwatch = boto3.client('cloudwatch')
            
            for source_name, result in transformation_results.items():
                if result['status'] == 'success':
                    cloudwatch.put_metric_data(
                        Namespace='ETL/Transform',
                        MetricData=[
                            {
                                'MetricName': 'RecordsTransformed',
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
        
        return transformation_results
        
    except Exception as e:
        logger.error(f"Transformation job failed: {str(e)}")
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

"""
AWS Glue ETL Job - Load Data to Data Warehouse
This job loads clean data from the clean zone and creates aggregated datasets for analytics.
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
    'CLEAN_ZONE_BUCKET',
    'AGGREGATED_ZONE_BUCKET',
    'TEMP_ZONE_BUCKET',
    'REDSHIFT_ENDPOINT',
    'REDSHIFT_DATABASE',
    'REDSHIFT_USERNAME',
    'REDSHIFT_PASSWORD'
])

job.init(args['JOB_NAME'], args)

# Configuration
CLEAN_ZONE_BUCKET = args['CLEAN_ZONE_BUCKET']
AGGREGATED_ZONE_BUCKET = args['AGGREGATED_ZONE_BUCKET']
TEMP_ZONE_BUCKET = args['TEMP_ZONE_BUCKET']
REDSHIFT_ENDPOINT = args.get('REDSHIFT_ENDPOINT', '')
REDSHIFT_DATABASE = args.get('REDSHIFT_DATABASE', '')
REDSHIFT_USERNAME = args.get('REDSHIFT_USERNAME', '')
REDSHIFT_PASSWORD = args.get('REDSHIFT_PASSWORD', '')

def read_clean_data(table_name):
    """
    Read clean data from S3
    """
    try:
        logger.info(f"Reading clean data for {table_name}")
        
        # Read from clean zone
        clean_path = f"s3://{CLEAN_ZONE_BUCKET}/tables/{table_name}/"
        df = spark.read.parquet(clean_path)
        
        logger.info(f"Loaded {df.count()} records for {table_name}")
        return df
        
    except Exception as e:
        logger.error(f"Error reading clean data for {table_name}: {str(e)}")
        raise

def create_legislators_aggregations(df):
    """
    Create aggregated datasets for legislators data
    """
    try:
        logger.info("Creating legislators aggregations")
        
        # State-level aggregations
        state_aggregations = df.groupBy("state", "extract_date") \
            .agg(
                count("*").alias("total_legislators"),
                countDistinct("party").alias("parties_represented"),
                sum(when(col("gender") == "Male", 1).otherwise(0)).alias("male_count"),
                sum(when(col("gender") == "Female", 1).otherwise(0)).alias("female_count"),
                sum(when(col("currently_in_office") == True, 1).otherwise(0)).alias("active_count")
            ) \
            .withColumn("male_percentage", (col("male_count") / col("total_legislators")) * 100) \
            .withColumn("female_percentage", (col("female_count") / col("total_legislators")) * 100) \
            .withColumn("aggregation_timestamp", current_timestamp())
        
        # Party-level aggregations
        party_aggregations = df.groupBy("party", "extract_date") \
            .agg(
                count("*").alias("total_legislators"),
                countDistinct("state").alias("states_represented"),
                sum(when(col("gender") == "Male", 1).otherwise(0)).alias("male_count"),
                sum(when(col("gender") == "Female", 1).otherwise(0)).alias("female_count"),
                sum(when(col("currently_in_office") == True, 1).otherwise(0)).alias("active_count")
            ) \
            .withColumn("male_percentage", (col("male_count") / col("total_legislators")) * 100) \
            .withColumn("female_percentage", (col("female_count") / col("total_legislators")) * 100) \
            .withColumn("aggregation_timestamp", current_timestamp())
        
        # Gender distribution
        gender_distribution = df.groupBy("gender", "extract_date") \
            .agg(
                count("*").alias("total_count"),
                countDistinct("state").alias("states_represented"),
                countDistinct("party").alias("parties_represented")
            ) \
            .withColumn("aggregation_timestamp", current_timestamp())
        
        logger.info("Created legislators aggregations")
        return {
            'state_aggregations': state_aggregations,
            'party_aggregations': party_aggregations,
            'gender_distribution': gender_distribution
        }
        
    except Exception as e:
        logger.error(f"Error creating legislators aggregations: {str(e)}")
        raise

def create_sales_aggregations(df):
    """
    Create aggregated datasets for sales data
    """
    try:
        logger.info("Creating sales aggregations")
        
        # Regional sales aggregations
        regional_sales = df.groupBy("region", "extract_date") \
            .agg(
                count("*").alias("total_sales"),
                sum("sale_amount").alias("total_revenue"),
                avg("sale_amount").alias("average_sale_amount"),
                min("sale_amount").alias("min_sale_amount"),
                max("sale_amount").alias("max_sale_amount"),
                countDistinct("customer_name").alias("unique_customers")
            ) \
            .withColumn("aggregation_timestamp", current_timestamp())
        
        # Product category aggregations
        category_sales = df.groupBy("product_category", "extract_date") \
            .agg(
                count("*").alias("total_sales"),
                sum("sale_amount").alias("total_revenue"),
                avg("sale_amount").alias("average_sale_amount"),
                countDistinct("customer_name").alias("unique_customers")
            ) \
            .withColumn("aggregation_timestamp", current_timestamp())
        
        # Daily sales trend
        daily_sales = df.groupBy("sale_date", "extract_date") \
            .agg(
                count("*").alias("total_sales"),
                sum("sale_amount").alias("daily_revenue"),
                avg("sale_amount").alias("average_sale_amount")
            ) \
            .withColumn("aggregation_timestamp", current_timestamp())
        
        logger.info("Created sales aggregations")
        return {
            'regional_sales': regional_sales,
            'category_sales': category_sales,
            'daily_sales': daily_sales
        }
        
    except Exception as e:
        logger.error(f"Error creating sales aggregations: {str(e)}")
        raise

def save_aggregated_data(aggregations, source_name):
    """
    Save aggregated data to aggregated zone
    """
    try:
        logger.info(f"Saving aggregated data for {source_name}")
        
        for aggregation_name, df in aggregations.items():
            # Define output path
            output_path = f"s3://{AGGREGATED_ZONE_BUCKET}/aggregations/{source_name}/{aggregation_name}/"
            
            # Partition by extract date
            df.write \
              .mode("overwrite") \
              .partitionBy("extract_date") \
              .parquet(output_path)
            
            # Save as Glue table
            table_name = f"agg_{source_name}_{aggregation_name}"
            df.write \
              .mode("overwrite") \
              .option("path", output_path) \
              .saveAsTable(table_name)
            
            logger.info(f"Saved {aggregation_name} to {output_path}")
        
        return True
        
    except Exception as e:
        logger.error(f"Error saving aggregated data for {source_name}: {str(e)}")
        raise

def load_to_redshift(df, table_name, redshift_config):
    """
    Load data to Redshift (if configured)
    """
    try:
        if not all([redshift_config.get('endpoint'), redshift_config.get('database'), 
                   redshift_config.get('username'), redshift_config.get('password')]):
            logger.info("Redshift configuration not complete, skipping Redshift load")
            return True
        
        logger.info(f"Loading {table_name} to Redshift")
        
        # Write to Redshift using Glue's built-in connector
        df.write \
          .format("jdbc") \
          .option("url", f"jdbc:redshift://{redshift_config['endpoint']}:5439/{redshift_config['database']}") \
          .option("dbtable", table_name) \
          .option("user", redshift_config['username']) \
          .option("password", redshift_config['password']) \
          .option("driver", "com.amazon.redshift.jdbc.Driver") \
          .mode("overwrite") \
          .save()
        
        logger.info(f"Successfully loaded {table_name} to Redshift")
        return True
        
    except Exception as e:
        logger.error(f"Error loading {table_name} to Redshift: {str(e)}")
        # Don't fail the job if Redshift load fails
        return False

def create_data_summary_report(aggregations, source_name):
    """
    Create a summary report of the loaded data
    """
    try:
        logger.info(f"Creating data summary report for {source_name}")
        
        summary_data = []
        
        for aggregation_name, df in aggregations.items():
            record_count = df.count()
            summary_data.append({
                'source_name': source_name,
                'aggregation_name': aggregation_name,
                'record_count': record_count,
                'load_timestamp': datetime.now(),
                'status': 'success' if record_count > 0 else 'empty'
            })
        
        # Create summary DataFrame
        summary_df = spark.createDataFrame(summary_data)
        
        # Save summary report
        summary_path = f"s3://{AGGREGATED_ZONE_BUCKET}/summary_reports/{source_name}/"
        summary_df.write \
          .mode("append") \
          .parquet(summary_path)
        
        logger.info(f"Data summary report saved for {source_name}")
        
    except Exception as e:
        logger.error(f"Error creating data summary report for {source_name}: {str(e)}")

def main():
    """
    Main load logic
    """
    try:
        logger.info("Starting data load job")
        
        # Redshift configuration
        redshift_config = {
            'endpoint': REDSHIFT_ENDPOINT,
            'database': REDSHIFT_DATABASE,
            'username': REDSHIFT_USERNAME,
            'password': REDSHIFT_PASSWORD
        }
        
        # Define load rules
        load_rules = {
            'legislators_clean': {
                'aggregation_function': create_legislators_aggregations,
                'redshift_tables': ['legislators_state_agg', 'legislators_party_agg', 'legislators_gender_agg']
            },
            'sample_sales_clean': {
                'aggregation_function': create_sales_aggregations,
                'redshift_tables': ['sales_regional_agg', 'sales_category_agg', 'sales_daily_agg']
            }
        }
        
        # Track load results
        load_results = {}
        
        # Process each clean dataset
        for table_name, load_config in load_rules.items():
            try:
                logger.info(f"Processing load for {table_name}")
                
                # Read clean data
                clean_df = read_clean_data(table_name)
                
                # Create aggregations
                aggregations = load_config['aggregation_function'](clean_df)
                
                # Save aggregated data
                source_name = table_name.replace('_clean', '')
                save_aggregated_data(aggregations, source_name)
                
                # Load to Redshift (if configured)
                redshift_success = True
                if redshift_config['endpoint']:
                    for i, (agg_name, df) in enumerate(aggregations.items()):
                        redshift_table = load_config['redshift_tables'][i] if i < len(load_config['redshift_tables']) else f"{source_name}_{agg_name}"
                        redshift_success &= load_to_redshift(df, redshift_table, redshift_config)
                
                # Create summary report
                create_data_summary_report(aggregations, source_name)
                
                # Calculate total records loaded
                total_records = sum(df.count() for df in aggregations.values())
                
                load_results[table_name] = {
                    'status': 'success',
                    'total_records': total_records,
                    'aggregations_created': len(aggregations),
                    'redshift_success': redshift_success
                }
                
            except Exception as e:
                logger.error(f"Failed to load {table_name}: {str(e)}")
                load_results[table_name] = {
                    'status': 'failed',
                    'reason': str(e)
                }
        
        # Log final results
        logger.info("Load job completed")
        logger.info(f"Results: {load_results}")
        
        # Send custom metrics to CloudWatch
        try:
            cloudwatch = boto3.client('cloudwatch')
            
            for table_name, result in load_results.items():
                if result['status'] == 'success':
                    cloudwatch.put_metric_data(
                        Namespace='ETL/Load',
                        MetricData=[
                            {
                                'MetricName': 'RecordsLoaded',
                                'Value': result['total_records'],
                                'Unit': 'Count',
                                'Dimensions': [
                                    {
                                        'Name': 'Table',
                                        'Value': table_name
                                    }
                                ]
                            },
                            {
                                'MetricName': 'AggregationsCreated',
                                'Value': result['aggregations_created'],
                                'Unit': 'Count',
                                'Dimensions': [
                                    {
                                        'Name': 'Table',
                                        'Value': table_name
                                    }
                                ]
                            }
                        ]
                    )
        except Exception as e:
            logger.warning(f"Failed to send metrics to CloudWatch: {str(e)}")
        
        return load_results
        
    except Exception as e:
        logger.error(f"Load job failed: {str(e)}")
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

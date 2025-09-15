#!/usr/bin/env python3
"""
Architecture 4: EMR Batch ETL - Spark Data Processing Job

This Spark job processes large-scale batch data using Apache Spark on EMR.
It demonstrates various data processing patterns including:
- Data ingestion from multiple sources
- Data transformation and cleaning
- Data aggregation and analytics
- Data quality validation
- Output to multiple destinations

Author: AWS ETL Architecture Team
Version: 1.0
"""

import sys
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional

from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import (
    col, when, isnan, isnull, count, sum, avg, max, min,
    date_format, year, month, dayofmonth, hour, minute,
    regexp_replace, trim, upper, lower, split, explode,
    row_number, rank, dense_rank, lag, lead, window,
    collect_list, collect_set, first, last, stddev, variance,
    corr, covar_pop, covar_samp, skewness, kurtosis,
    percentile_approx, approx_count_distinct, monotonically_increasing_id
)
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType, 
    DoubleType, BooleanType, TimestampType, DateType,
    ArrayType, MapType
)
from pyspark.sql.window import Window
from pyspark.ml import Pipeline
from pyspark.ml.feature import (
    VectorAssembler, StandardScaler, MinMaxScaler,
    StringIndexer, OneHotEncoder, Bucketizer
)
from pyspark.ml.classification import RandomForestClassifier, LogisticRegression
from pyspark.ml.regression import RandomForestRegressor, LinearRegression
from pyspark.ml.clustering import KMeans
from pyspark.ml.evaluation import (
    MulticlassClassificationEvaluator, RegressionEvaluator,
    ClusteringEvaluator
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class EMRBatchETLProcessor:
    """
    EMR Batch ETL Processor for large-scale data processing
    """
    
    def __init__(self, spark_session: SparkSession, config: Dict[str, Any]):
        """
        Initialize the EMR Batch ETL Processor
        
        Args:
            spark_session: Spark session
            config: Configuration dictionary
        """
        self.spark = spark_session
        self.config = config
        self.logger = logging.getLogger(self.__class__.__name__)
        
        # Set Spark configurations
        self._configure_spark()
        
        # Initialize data quality metrics
        self.quality_metrics = {}
        
    def _configure_spark(self):
        """Configure Spark session for optimal performance"""
        try:
            # Set Spark configurations for EMR
            self.spark.conf.set("spark.sql.adaptive.enabled", "true")
            self.spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
            self.spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
            self.spark.conf.set("spark.sql.adaptive.localShuffleReader.enabled", "true")
            
            # Parquet optimizations
            self.spark.conf.set("spark.sql.parquet.compression.codec", "snappy")
            self.spark.conf.set("spark.sql.parquet.mergeSchema", "false")
            self.spark.conf.set("spark.sql.parquet.filterPushdown", "true")
            
            # Memory optimizations
            self.spark.conf.set("spark.sql.execution.arrow.pyspark.enabled", "true")
            self.spark.conf.set("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
            
            # Dynamic partition pruning
            self.spark.conf.set("spark.sql.optimizer.dynamicPartitionPruning.enabled", "true")
            
            self.logger.info("Spark configuration completed successfully")
            
        except Exception as e:
            self.logger.error(f"Error configuring Spark: {str(e)}")
            raise
    
    def read_data(self, source_config: Dict[str, Any]) -> DataFrame:
        """
        Read data from various sources
        
        Args:
            source_config: Source configuration
            
        Returns:
            DataFrame: Loaded data
        """
        try:
            source_type = source_config.get("type", "s3")
            source_path = source_config.get("path")
            file_format = source_config.get("format", "parquet")
            
            self.logger.info(f"Reading data from {source_type}: {source_path}")
            
            if source_type == "s3":
                return self._read_from_s3(source_path, file_format, source_config)
            elif source_type == "hdfs":
                return self._read_from_hdfs(source_path, file_format, source_config)
            elif source_type == "jdbc":
                return self._read_from_jdbc(source_config)
            else:
                raise ValueError(f"Unsupported source type: {source_type}")
                
        except Exception as e:
            self.logger.error(f"Error reading data: {str(e)}")
            raise
    
    def _read_from_s3(self, path: str, file_format: str, config: Dict[str, Any]) -> DataFrame:
        """Read data from S3"""
        try:
            reader = self.spark.read
            
            # Apply schema if provided
            if "schema" in config:
                schema = self._create_schema(config["schema"])
                reader = reader.schema(schema)
            
            # Apply options
            if "options" in config:
                reader = reader.options(**config["options"])
            
            # Read based on format
            if file_format.lower() == "parquet":
                return reader.parquet(path)
            elif file_format.lower() == "json":
                return reader.json(path)
            elif file_format.lower() == "csv":
                return reader.csv(path, header=True, inferSchema=True)
            elif file_format.lower() == "delta":
                return reader.format("delta").load(path)
            else:
                raise ValueError(f"Unsupported file format: {file_format}")
                
        except Exception as e:
            self.logger.error(f"Error reading from S3: {str(e)}")
            raise
    
    def _read_from_hdfs(self, path: str, file_format: str, config: Dict[str, Any]) -> DataFrame:
        """Read data from HDFS"""
        try:
            reader = self.spark.read
            
            if "schema" in config:
                schema = self._create_schema(config["schema"])
                reader = reader.schema(schema)
            
            if "options" in config:
                reader = reader.options(**config["options"])
            
            if file_format.lower() == "parquet":
                return reader.parquet(path)
            elif file_format.lower() == "json":
                return reader.json(path)
            elif file_format.lower() == "csv":
                return reader.csv(path, header=True, inferSchema=True)
            else:
                raise ValueError(f"Unsupported file format: {file_format}")
                
        except Exception as e:
            self.logger.error(f"Error reading from HDFS: {str(e)}")
            raise
    
    def _read_from_jdbc(self, config: Dict[str, Any]) -> DataFrame:
        """Read data from JDBC source"""
        try:
            jdbc_url = config["jdbc_url"]
            table = config["table"]
            properties = config.get("properties", {})
            
            return self.spark.read.jdbc(jdbc_url, table, properties=properties)
            
        except Exception as e:
            self.logger.error(f"Error reading from JDBC: {str(e)}")
            raise
    
    def _create_schema(self, schema_config: List[Dict[str, Any]]) -> StructType:
        """Create Spark schema from configuration"""
        try:
            fields = []
            for field_config in schema_config:
                field_name = field_config["name"]
                field_type = field_config["type"]
                nullable = field_config.get("nullable", True)
                
                # Map type strings to Spark types
                spark_type = self._get_spark_type(field_type)
                
                fields.append(StructField(field_name, spark_type, nullable))
            
            return StructType(fields)
            
        except Exception as e:
            self.logger.error(f"Error creating schema: {str(e)}")
            raise
    
    def _get_spark_type(self, type_str: str):
        """Map type string to Spark type"""
        type_mapping = {
            "string": StringType(),
            "integer": IntegerType(),
            "double": DoubleType(),
            "boolean": BooleanType(),
            "timestamp": TimestampType(),
            "date": DateType()
        }
        
        if type_str in type_mapping:
            return type_mapping[type_str]
        else:
            raise ValueError(f"Unsupported type: {type_str}")
    
    def validate_data_quality(self, df: DataFrame, quality_config: Dict[str, Any]) -> Dict[str, Any]:
        """
        Validate data quality
        
        Args:
            df: DataFrame to validate
            quality_config: Quality validation configuration
            
        Returns:
            Dict: Quality metrics
        """
        try:
            self.logger.info("Starting data quality validation")
            
            quality_metrics = {
                "total_records": df.count(),
                "total_columns": len(df.columns),
                "validation_timestamp": datetime.now().isoformat()
            }
            
            # Check for null values
            if "null_checks" in quality_config:
                null_metrics = self._check_null_values(df, quality_config["null_checks"])
                quality_metrics.update(null_metrics)
            
            # Check for duplicates
            if "duplicate_checks" in quality_config:
                duplicate_metrics = self._check_duplicates(df, quality_config["duplicate_checks"])
                quality_metrics.update(duplicate_metrics)
            
            # Check data ranges
            if "range_checks" in quality_config:
                range_metrics = self._check_data_ranges(df, quality_config["range_checks"])
                quality_metrics.update(range_metrics)
            
            # Check data patterns
            if "pattern_checks" in quality_config:
                pattern_metrics = self._check_data_patterns(df, quality_config["pattern_checks"])
                quality_metrics.update(pattern_metrics)
            
            self.quality_metrics = quality_metrics
            self.logger.info(f"Data quality validation completed: {quality_metrics}")
            
            return quality_metrics
            
        except Exception as e:
            self.logger.error(f"Error in data quality validation: {str(e)}")
            raise
    
    def _check_null_values(self, df: DataFrame, null_config: Dict[str, Any]) -> Dict[str, Any]:
        """Check for null values in specified columns"""
        try:
            columns_to_check = null_config.get("columns", df.columns)
            max_null_percentage = null_config.get("max_null_percentage", 10.0)
            
            null_metrics = {}
            total_records = df.count()
            
            for column in columns_to_check:
                null_count = df.filter(col(column).isNull()).count()
                null_percentage = (null_count / total_records) * 100
                
                null_metrics[f"{column}_null_count"] = null_count
                null_metrics[f"{column}_null_percentage"] = null_percentage
                null_metrics[f"{column}_null_check_passed"] = null_percentage <= max_null_percentage
            
            return null_metrics
            
        except Exception as e:
            self.logger.error(f"Error checking null values: {str(e)}")
            raise
    
    def _check_duplicates(self, df: DataFrame, duplicate_config: Dict[str, Any]) -> Dict[str, Any]:
        """Check for duplicate records"""
        try:
            key_columns = duplicate_config.get("key_columns", df.columns)
            max_duplicate_percentage = duplicate_config.get("max_duplicate_percentage", 5.0)
            
            total_records = df.count()
            distinct_records = df.select(*key_columns).distinct().count()
            duplicate_count = total_records - distinct_records
            duplicate_percentage = (duplicate_count / total_records) * 100
            
            return {
                "total_records": total_records,
                "distinct_records": distinct_records,
                "duplicate_count": duplicate_count,
                "duplicate_percentage": duplicate_percentage,
                "duplicate_check_passed": duplicate_percentage <= max_duplicate_percentage
            }
            
        except Exception as e:
            self.logger.error(f"Error checking duplicates: {str(e)}")
            raise
    
    def _check_data_ranges(self, df: DataFrame, range_config: Dict[str, Any]) -> Dict[str, Any]:
        """Check data ranges for numeric columns"""
        try:
            range_metrics = {}
            
            for column_config in range_config.get("columns", []):
                column_name = column_config["column"]
                min_value = column_config.get("min_value")
                max_value = column_config.get("max_value")
                
                if min_value is not None:
                    out_of_range_min = df.filter(col(column_name) < min_value).count()
                    range_metrics[f"{column_name}_below_min"] = out_of_range_min
                
                if max_value is not None:
                    out_of_range_max = df.filter(col(column_name) > max_value).count()
                    range_metrics[f"{column_name}_above_max"] = out_of_range_max
            
            return range_metrics
            
        except Exception as e:
            self.logger.error(f"Error checking data ranges: {str(e)}")
            raise
    
    def _check_data_patterns(self, df: DataFrame, pattern_config: Dict[str, Any]) -> Dict[str, Any]:
        """Check data patterns for string columns"""
        try:
            pattern_metrics = {}
            
            for column_config in pattern_config.get("columns", []):
                column_name = column_config["column"]
                pattern = column_config["pattern"]
                
                # Count records that don't match the pattern
                non_matching = df.filter(~col(column_name).rlike(pattern)).count()
                total_records = df.count()
                non_matching_percentage = (non_matching / total_records) * 100
                
                pattern_metrics[f"{column_name}_non_matching_pattern"] = non_matching
                pattern_metrics[f"{column_name}_non_matching_percentage"] = non_matching_percentage
            
            return pattern_metrics
            
        except Exception as e:
            self.logger.error(f"Error checking data patterns: {str(e)}")
            raise
    
    def transform_data(self, df: DataFrame, transformation_config: Dict[str, Any]) -> DataFrame:
        """
        Transform data based on configuration
        
        Args:
            df: Input DataFrame
            transformation_config: Transformation configuration
            
        Returns:
            DataFrame: Transformed data
        """
        try:
            self.logger.info("Starting data transformation")
            
            transformed_df = df
            
            # Apply data cleaning
            if "data_cleaning" in transformation_config:
                transformed_df = self._apply_data_cleaning(transformed_df, transformation_config["data_cleaning"])
            
            # Apply data enrichment
            if "data_enrichment" in transformation_config:
                transformed_df = self._apply_data_enrichment(transformed_df, transformation_config["data_enrichment"])
            
            # Apply data aggregation
            if "data_aggregation" in transformation_config:
                transformed_df = self._apply_data_aggregation(transformed_df, transformation_config["data_aggregation"])
            
            # Apply business logic
            if "business_logic" in transformation_config:
                transformed_df = self._apply_business_logic(transformed_df, transformation_config["business_logic"])
            
            self.logger.info("Data transformation completed successfully")
            return transformed_df
            
        except Exception as e:
            self.logger.error(f"Error in data transformation: {str(e)}")
            raise
    
    def _apply_data_cleaning(self, df: DataFrame, cleaning_config: Dict[str, Any]) -> DataFrame:
        """Apply data cleaning transformations"""
        try:
            cleaned_df = df
            
            # Handle null values
            if "null_handling" in cleaning_config:
                null_config = cleaning_config["null_handling"]
                for column, strategy in null_config.items():
                    if strategy == "drop":
                        cleaned_df = cleaned_df.filter(col(column).isNotNull())
                    elif strategy == "fill_default":
                        default_value = null_config.get(f"{column}_default", "")
                        cleaned_df = cleaned_df.fillna({column: default_value})
                    elif strategy == "fill_mean":
                        mean_value = cleaned_df.select(avg(col(column))).collect()[0][0]
                        cleaned_df = cleaned_df.fillna({column: mean_value})
            
            # Handle duplicates
            if "duplicate_handling" in cleaning_config:
                duplicate_config = cleaning_config["duplicate_handling"]
                if duplicate_config.get("strategy") == "remove":
                    key_columns = duplicate_config.get("key_columns", cleaned_df.columns)
                    cleaned_df = cleaned_df.dropDuplicates(key_columns)
            
            # Data type conversions
            if "type_conversions" in cleaning_config:
                type_config = cleaning_config["type_conversions"]
                for column, target_type in type_config.items():
                    if target_type == "string":
                        cleaned_df = cleaned_df.withColumn(column, col(column).cast(StringType()))
                    elif target_type == "integer":
                        cleaned_df = cleaned_df.withColumn(column, col(column).cast(IntegerType()))
                    elif target_type == "double":
                        cleaned_df = cleaned_df.withColumn(column, col(column).cast(DoubleType()))
            
            # String cleaning
            if "string_cleaning" in cleaning_config:
                string_config = cleaning_config["string_cleaning"]
                for column in string_config.get("columns", []):
                    if string_config.get("trim", False):
                        cleaned_df = cleaned_df.withColumn(column, trim(col(column)))
                    if string_config.get("uppercase", False):
                        cleaned_df = cleaned_df.withColumn(column, upper(col(column)))
                    if string_config.get("lowercase", False):
                        cleaned_df = cleaned_df.withColumn(column, lower(col(column)))
                    if string_config.get("remove_special_chars", False):
                        cleaned_df = cleaned_df.withColumn(column, regexp_replace(col(column), "[^a-zA-Z0-9\\s]", ""))
            
            return cleaned_df
            
        except Exception as e:
            self.logger.error(f"Error in data cleaning: {str(e)}")
            raise
    
    def _apply_data_enrichment(self, df: DataFrame, enrichment_config: Dict[str, Any]) -> DataFrame:
        """Apply data enrichment transformations"""
        try:
            enriched_df = df
            
            # Add timestamp columns
            if "timestamp_columns" in enrichment_config:
                timestamp_config = enrichment_config["timestamp_columns"]
                for column_name, format_string in timestamp_config.items():
                    enriched_df = enriched_df.withColumn(column_name, date_format(col("timestamp"), format_string))
            
            # Add derived columns
            if "derived_columns" in enrichment_config:
                derived_config = enrichment_config["derived_columns"]
                for column_name, expression in derived_config.items():
                    enriched_df = enriched_df.withColumn(column_name, expr(expression))
            
            # Add window functions
            if "window_functions" in enrichment_config:
                window_config = enrichment_config["window_functions"]
                for column_name, window_spec in window_config.items():
                    window = Window.partitionBy(window_spec["partition_by"]).orderBy(window_spec["order_by"])
                    function_type = window_spec["function"]
                    
                    if function_type == "row_number":
                        enriched_df = enriched_df.withColumn(column_name, row_number().over(window))
                    elif function_type == "rank":
                        enriched_df = enriched_df.withColumn(column_name, rank().over(window))
                    elif function_type == "lag":
                        offset = window_spec.get("offset", 1)
                        enriched_df = enriched_df.withColumn(column_name, lag(col(window_spec["column"]), offset).over(window))
                    elif function_type == "lead":
                        offset = window_spec.get("offset", 1)
                        enriched_df = enriched_df.withColumn(column_name, lead(col(window_spec["column"]), offset).over(window))
            
            return enriched_df
            
        except Exception as e:
            self.logger.error(f"Error in data enrichment: {str(e)}")
            raise
    
    def _apply_data_aggregation(self, df: DataFrame, aggregation_config: Dict[str, Any]) -> DataFrame:
        """Apply data aggregation transformations"""
        try:
            # Group by columns
            group_by_columns = aggregation_config.get("group_by", [])
            
            if not group_by_columns:
                return df
            
            # Aggregation functions
            aggregation_functions = aggregation_config.get("aggregations", {})
            
            if not aggregation_functions:
                return df.groupBy(*group_by_columns).count()
            
            # Apply aggregations
            agg_exprs = []
            for column, functions in aggregation_functions.items():
                for function in functions:
                    if function == "count":
                        agg_exprs.append(count(col(column)).alias(f"{column}_count"))
                    elif function == "sum":
                        agg_exprs.append(sum(col(column)).alias(f"{column}_sum"))
                    elif function == "avg":
                        agg_exprs.append(avg(col(column)).alias(f"{column}_avg"))
                    elif function == "max":
                        agg_exprs.append(max(col(column)).alias(f"{column}_max"))
                    elif function == "min":
                        agg_exprs.append(min(col(column)).alias(f"{column}_min"))
                    elif function == "stddev":
                        agg_exprs.append(stddev(col(column)).alias(f"{column}_stddev"))
                    elif function == "variance":
                        agg_exprs.append(variance(col(column)).alias(f"{column}_variance"))
            
            return df.groupBy(*group_by_columns).agg(*agg_exprs)
            
        except Exception as e:
            self.logger.error(f"Error in data aggregation: {str(e)}")
            raise
    
    def _apply_business_logic(self, df: DataFrame, business_config: Dict[str, Any]) -> DataFrame:
        """Apply business logic transformations"""
        try:
            business_df = df
            
            # Conditional logic
            if "conditional_logic" in business_config:
                conditional_config = business_config["conditional_logic"]
                for column_name, conditions in conditional_config.items():
                    case_expr = when(col(conditions["column"]) == conditions["value"], conditions["then_value"])
                    for condition in conditions.get("additional_conditions", []):
                        case_expr = case_expr.when(col(condition["column"]) == condition["value"], condition["then_value"])
                    case_expr = case_expr.otherwise(conditions.get("else_value", None))
                    business_df = business_df.withColumn(column_name, case_expr)
            
            # Data filtering
            if "filtering" in business_config:
                filter_config = business_config["filtering"]
                for filter_condition in filter_config.get("conditions", []):
                    column = filter_condition["column"]
                    operator = filter_condition["operator"]
                    value = filter_condition["value"]
                    
                    if operator == "equals":
                        business_df = business_df.filter(col(column) == value)
                    elif operator == "not_equals":
                        business_df = business_df.filter(col(column) != value)
                    elif operator == "greater_than":
                        business_df = business_df.filter(col(column) > value)
                    elif operator == "less_than":
                        business_df = business_df.filter(col(column) < value)
                    elif operator == "in":
                        business_df = business_df.filter(col(column).isin(value))
                    elif operator == "not_in":
                        business_df = business_df.filter(~col(column).isin(value))
            
            return business_df
            
        except Exception as e:
            self.logger.error(f"Error in business logic: {str(e)}")
            raise
    
    def write_data(self, df: DataFrame, output_config: Dict[str, Any]):
        """
        Write data to various destinations
        
        Args:
            df: DataFrame to write
            output_config: Output configuration
        """
        try:
            output_type = output_config.get("type", "s3")
            output_path = output_config.get("path")
            file_format = output_config.get("format", "parquet")
            
            self.logger.info(f"Writing data to {output_type}: {output_path}")
            
            if output_type == "s3":
                self._write_to_s3(df, output_path, file_format, output_config)
            elif output_type == "hdfs":
                self._write_to_hdfs(df, output_path, file_format, output_config)
            elif output_type == "jdbc":
                self._write_to_jdbc(df, output_config)
            else:
                raise ValueError(f"Unsupported output type: {output_type}")
                
        except Exception as e:
            self.logger.error(f"Error writing data: {str(e)}")
            raise
    
    def _write_to_s3(self, df: DataFrame, path: str, file_format: str, config: Dict[str, Any]):
        """Write data to S3"""
        try:
            writer = df.write
            
            # Apply options
            if "options" in config:
                writer = writer.options(**config["options"])
            
            # Apply partitioning
            if "partition_by" in config:
                writer = writer.partitionBy(*config["partition_by"])
            
            # Apply mode
            mode = config.get("mode", "overwrite")
            writer = writer.mode(mode)
            
            # Write based on format
            if file_format.lower() == "parquet":
                writer.parquet(path)
            elif file_format.lower() == "json":
                writer.json(path)
            elif file_format.lower() == "csv":
                writer.csv(path, header=True)
            elif file_format.lower() == "delta":
                writer.format("delta").save(path)
            else:
                raise ValueError(f"Unsupported file format: {file_format}")
                
            self.logger.info(f"Successfully wrote data to S3: {path}")
            
        except Exception as e:
            self.logger.error(f"Error writing to S3: {str(e)}")
            raise
    
    def _write_to_hdfs(self, df: DataFrame, path: str, file_format: str, config: Dict[str, Any]):
        """Write data to HDFS"""
        try:
            writer = df.write
            
            if "options" in config:
                writer = writer.options(**config["options"])
            
            if "partition_by" in config:
                writer = writer.partitionBy(*config["partition_by"])
            
            mode = config.get("mode", "overwrite")
            writer = writer.mode(mode)
            
            if file_format.lower() == "parquet":
                writer.parquet(path)
            elif file_format.lower() == "json":
                writer.json(path)
            elif file_format.lower() == "csv":
                writer.csv(path, header=True)
            else:
                raise ValueError(f"Unsupported file format: {file_format}")
                
            self.logger.info(f"Successfully wrote data to HDFS: {path}")
            
        except Exception as e:
            self.logger.error(f"Error writing to HDFS: {str(e)}")
            raise
    
    def _write_to_jdbc(self, df: DataFrame, config: Dict[str, Any]):
        """Write data to JDBC destination"""
        try:
            jdbc_url = config["jdbc_url"]
            table = config["table"]
            properties = config.get("properties", {})
            mode = config.get("mode", "overwrite")
            
            df.write.jdbc(jdbc_url, table, mode=mode, properties=properties)
            
            self.logger.info(f"Successfully wrote data to JDBC: {table}")
            
        except Exception as e:
            self.logger.error(f"Error writing to JDBC: {str(e)}")
            raise
    
    def run_ml_pipeline(self, df: DataFrame, ml_config: Dict[str, Any]) -> Dict[str, Any]:
        """
        Run machine learning pipeline
        
        Args:
            df: Input DataFrame
            ml_config: ML configuration
            
        Returns:
            Dict: ML results
        """
        try:
            self.logger.info("Starting ML pipeline")
            
            ml_results = {}
            
            # Feature engineering
            if "feature_engineering" in ml_config:
                feature_df = self._apply_feature_engineering(df, ml_config["feature_engineering"])
            else:
                feature_df = df
            
            # Model training
            if "model_training" in ml_config:
                model_results = self._train_models(feature_df, ml_config["model_training"])
                ml_results.update(model_results)
            
            # Model evaluation
            if "model_evaluation" in ml_config:
                evaluation_results = self._evaluate_models(feature_df, ml_config["model_evaluation"])
                ml_results.update(evaluation_results)
            
            self.logger.info("ML pipeline completed successfully")
            return ml_results
            
        except Exception as e:
            self.logger.error(f"Error in ML pipeline: {str(e)}")
            raise
    
    def _apply_feature_engineering(self, df: DataFrame, feature_config: Dict[str, Any]) -> DataFrame:
        """Apply feature engineering transformations"""
        try:
            feature_df = df
            
            # String indexing
            if "string_indexing" in feature_config:
                string_config = feature_config["string_indexing"]
                for column in string_config.get("columns", []):
                    indexer = StringIndexer(inputCol=column, outputCol=f"{column}_indexed")
                    feature_df = indexer.fit(feature_df).transform(feature_df)
            
            # One-hot encoding
            if "one_hot_encoding" in feature_config:
                onehot_config = feature_config["one_hot_encoding"]
                for column in onehot_config.get("columns", []):
                    encoder = OneHotEncoder(inputCol=f"{column}_indexed", outputCol=f"{column}_encoded")
                    feature_df = encoder.transform(feature_df)
            
            # Vector assembly
            if "vector_assembly" in feature_config:
                vector_config = feature_config["vector_assembly"]
                feature_columns = vector_config.get("feature_columns", [])
                assembler = VectorAssembler(inputCols=feature_columns, outputCol="features")
                feature_df = assembler.transform(feature_df)
            
            # Feature scaling
            if "feature_scaling" in feature_config:
                scaling_config = feature_config["feature_scaling"]
                scaling_type = scaling_config.get("type", "standard")
                
                if scaling_type == "standard":
                    scaler = StandardScaler(inputCol="features", outputCol="scaled_features")
                elif scaling_type == "minmax":
                    scaler = MinMaxScaler(inputCol="features", outputCol="scaled_features")
                else:
                    raise ValueError(f"Unsupported scaling type: {scaling_type}")
                
                feature_df = scaler.fit(feature_df).transform(feature_df)
            
            return feature_df
            
        except Exception as e:
            self.logger.error(f"Error in feature engineering: {str(e)}")
            raise
    
    def _train_models(self, df: DataFrame, training_config: Dict[str, Any]) -> Dict[str, Any]:
        """Train machine learning models"""
        try:
            model_results = {}
            
            # Classification models
            if "classification" in training_config:
                classification_config = training_config["classification"]
                target_column = classification_config["target_column"]
                feature_column = classification_config.get("feature_column", "features")
                
                # Random Forest Classifier
                if "random_forest" in classification_config:
                    rf_config = classification_config["random_forest"]
                    rf = RandomForestClassifier(
                        featuresCol=feature_column,
                        labelCol=target_column,
                        numTrees=rf_config.get("num_trees", 100),
                        maxDepth=rf_config.get("max_depth", 5)
                    )
                    rf_model = rf.fit(df)
                    model_results["random_forest_classifier"] = rf_model
                
                # Logistic Regression
                if "logistic_regression" in classification_config:
                    lr_config = classification_config["logistic_regression"]
                    lr = LogisticRegression(
                        featuresCol=feature_column,
                        labelCol=target_column,
                        maxIter=lr_config.get("max_iter", 100)
                    )
                    lr_model = lr.fit(df)
                    model_results["logistic_regression"] = lr_model
            
            # Regression models
            if "regression" in training_config:
                regression_config = training_config["regression"]
                target_column = regression_config["target_column"]
                feature_column = regression_config.get("feature_column", "features")
                
                # Random Forest Regressor
                if "random_forest" in regression_config:
                    rf_config = regression_config["random_forest"]
                    rf = RandomForestRegressor(
                        featuresCol=feature_column,
                        labelCol=target_column,
                        numTrees=rf_config.get("num_trees", 100),
                        maxDepth=rf_config.get("max_depth", 5)
                    )
                    rf_model = rf.fit(df)
                    model_results["random_forest_regressor"] = rf_model
                
                # Linear Regression
                if "linear_regression" in regression_config:
                    lr_config = regression_config["linear_regression"]
                    lr = LinearRegression(
                        featuresCol=feature_column,
                        labelCol=target_column,
                        maxIter=lr_config.get("max_iter", 100)
                    )
                    lr_model = lr.fit(df)
                    model_results["linear_regression"] = lr_model
            
            # Clustering models
            if "clustering" in training_config:
                clustering_config = training_config["clustering"]
                feature_column = clustering_config.get("feature_column", "features")
                
                # K-Means
                if "kmeans" in clustering_config:
                    kmeans_config = clustering_config["kmeans"]
                    kmeans = KMeans(
                        featuresCol=feature_column,
                        k=kmeans_config.get("k", 3),
                        maxIter=kmeans_config.get("max_iter", 20)
                    )
                    kmeans_model = kmeans.fit(df)
                    model_results["kmeans"] = kmeans_model
            
            return model_results
            
        except Exception as e:
            self.logger.error(f"Error in model training: {str(e)}")
            raise
    
    def _evaluate_models(self, df: DataFrame, evaluation_config: Dict[str, Any]) -> Dict[str, Any]:
        """Evaluate machine learning models"""
        try:
            evaluation_results = {}
            
            # Classification evaluation
            if "classification" in evaluation_config:
                classification_config = evaluation_config["classification"]
                target_column = classification_config["target_column"]
                prediction_column = classification_config.get("prediction_column", "prediction")
                
                # Multiclass classification evaluator
                evaluator = MulticlassClassificationEvaluator(
                    labelCol=target_column,
                    predictionCol=prediction_column,
                    metricName="accuracy"
                )
                
                # Calculate accuracy
                accuracy = evaluator.evaluate(df)
                evaluation_results["classification_accuracy"] = accuracy
                
                # Calculate other metrics
                evaluator.setMetricName("f1")
                f1_score = evaluator.evaluate(df)
                evaluation_results["classification_f1"] = f1_score
            
            # Regression evaluation
            if "regression" in evaluation_config:
                regression_config = evaluation_config["regression"]
                target_column = regression_config["target_column"]
                prediction_column = regression_config.get("prediction_column", "prediction")
                
                # Regression evaluator
                evaluator = RegressionEvaluator(
                    labelCol=target_column,
                    predictionCol=prediction_column,
                    metricName="rmse"
                )
                
                # Calculate RMSE
                rmse = evaluator.evaluate(df)
                evaluation_results["regression_rmse"] = rmse
                
                # Calculate other metrics
                evaluator.setMetricName("r2")
                r2_score = evaluator.evaluate(df)
                evaluation_results["regression_r2"] = r2_score
            
            # Clustering evaluation
            if "clustering" in evaluation_config:
                clustering_config = evaluation_config["clustering"]
                feature_column = clustering_config.get("feature_column", "features")
                prediction_column = clustering_config.get("prediction_column", "prediction")
                
                # Clustering evaluator
                evaluator = ClusteringEvaluator(
                    featuresCol=feature_column,
                    predictionCol=prediction_column
                )
                
                # Calculate silhouette score
                silhouette_score = evaluator.evaluate(df)
                evaluation_results["clustering_silhouette"] = silhouette_score
            
            return evaluation_results
            
        except Exception as e:
            self.logger.error(f"Error in model evaluation: {str(e)}")
            raise
    
    def generate_report(self, output_path: str):
        """
        Generate processing report
        
        Args:
            output_path: Path to save the report
        """
        try:
            self.logger.info("Generating processing report")
            
            report = {
                "processing_timestamp": datetime.now().isoformat(),
                "spark_configuration": {
                    "spark_version": self.spark.version,
                    "app_name": self.spark.conf.get("spark.app.name"),
                    "master": self.spark.conf.get("spark.master")
                },
                "data_quality_metrics": self.quality_metrics,
                "processing_summary": {
                    "total_records_processed": self.quality_metrics.get("total_records", 0),
                    "total_columns": self.quality_metrics.get("total_columns", 0),
                    "validation_passed": all(
                        metric.get("validation_passed", True) 
                        for metric in self.quality_metrics.values() 
                        if isinstance(metric, dict) and "validation_passed" in metric
                    )
                }
            }
            
            # Save report to S3
            report_json = json.dumps(report, indent=2)
            self.spark.sparkContext.parallelize([report_json]).saveAsTextFile(output_path)
            
            self.logger.info(f"Processing report saved to: {output_path}")
            
        except Exception as e:
            self.logger.error(f"Error generating report: {str(e)}")
            raise


def main():
    """Main function to run the EMR Batch ETL job"""
    try:
        # Initialize Spark session
        spark = SparkSession.builder \
            .appName("EMR-Batch-ETL-Processor") \
            .config("spark.sql.adaptive.enabled", "true") \
            .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
            .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer") \
            .getOrCreate()
        
        # Set log level
        spark.sparkContext.setLogLevel("INFO")
        
        # Load configuration
        config_path = sys.argv[1] if len(sys.argv) > 1 else "s3://your-bucket/config/emr_batch_config.json"
        config = json.loads(spark.sparkContext.textFile(config_path).collect()[0])
        
        # Initialize processor
        processor = EMRBatchETLProcessor(spark, config)
        
        # Process each data source
        for source_config in config.get("data_sources", []):
            # Read data
            df = processor.read_data(source_config)
            
            # Validate data quality
            quality_metrics = processor.validate_data_quality(df, config.get("data_quality", {}))
            
            # Transform data
            transformed_df = processor.transform_data(df, config.get("transformations", {}))
            
            # Write data
            for output_config in config.get("outputs", []):
                processor.write_data(transformed_df, output_config)
            
            # Run ML pipeline if configured
            if "ml_pipeline" in config:
                ml_results = processor.run_ml_pipeline(transformed_df, config["ml_pipeline"])
                print(f"ML Results: {ml_results}")
        
        # Generate report
        report_path = config.get("report_path", "s3://your-bucket/reports/emr_batch_report")
        processor.generate_report(report_path)
        
        # Stop Spark session
        spark.stop()
        
        print("EMR Batch ETL job completed successfully!")
        
    except Exception as e:
        print(f"Error in EMR Batch ETL job: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()

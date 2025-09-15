#!/usr/bin/env python3
"""
Architecture 4: EMR Batch ETL - ML Pipeline

This module provides machine learning capabilities for the EMR batch ETL pipeline.
It includes feature engineering, model training, and evaluation components.

Author: AWS ETL Architecture Team
Version: 1.0
"""

import logging
from typing import Dict, List, Any, Optional
from pyspark.sql import DataFrame
from pyspark.ml import Pipeline
from pyspark.ml.feature import (
    VectorAssembler, StandardScaler, MinMaxScaler,
    StringIndexer, OneHotEncoder, Bucketizer, PCA
)
from pyspark.ml.classification import RandomForestClassifier, LogisticRegression, GBTClassifier
from pyspark.ml.regression import RandomForestRegressor, LinearRegression, GBTRegressor
from pyspark.ml.clustering import KMeans, BisectingKMeans
from pyspark.ml.evaluation import (
    MulticlassClassificationEvaluator, RegressionEvaluator,
    ClusteringEvaluator, BinaryClassificationEvaluator
)

logger = logging.getLogger(__name__)

class EMRMLPipeline:
    """Machine Learning Pipeline for EMR Batch ETL"""
    
    def __init__(self, spark_session):
        self.spark = spark_session
        self.logger = logging.getLogger(self.__class__.__name__)
    
    def run_feature_engineering(self, df: DataFrame, config: Dict[str, Any]) -> DataFrame:
        """Run feature engineering pipeline"""
        try:
            self.logger.info("Starting feature engineering")
            
            feature_df = df
            
            # String indexing
            if "string_indexing" in config:
                feature_df = self._apply_string_indexing(feature_df, config["string_indexing"])
            
            # One-hot encoding
            if "one_hot_encoding" in config:
                feature_df = self._apply_one_hot_encoding(feature_df, config["one_hot_encoding"])
            
            # Vector assembly
            if "vector_assembly" in config:
                feature_df = self._apply_vector_assembly(feature_df, config["vector_assembly"])
            
            # Feature scaling
            if "feature_scaling" in config:
                feature_df = self._apply_feature_scaling(feature_df, config["feature_scaling"])
            
            # PCA
            if "pca" in config:
                feature_df = self._apply_pca(feature_df, config["pca"])
            
            self.logger.info("Feature engineering completed")
            return feature_df
            
        except Exception as e:
            self.logger.error(f"Error in feature engineering: {str(e)}")
            raise
    
    def train_models(self, df: DataFrame, config: Dict[str, Any]) -> Dict[str, Any]:
        """Train machine learning models"""
        try:
            self.logger.info("Starting model training")
            
            models = {}
            
            # Classification models
            if "classification" in config:
                models.update(self._train_classification_models(df, config["classification"]))
            
            # Regression models
            if "regression" in config:
                models.update(self._train_regression_models(df, config["regression"]))
            
            # Clustering models
            if "clustering" in config:
                models.update(self._train_clustering_models(df, config["clustering"]))
            
            self.logger.info("Model training completed")
            return models
            
        except Exception as e:
            self.logger.error(f"Error in model training: {str(e)}")
            raise
    
    def evaluate_models(self, df: DataFrame, models: Dict[str, Any], config: Dict[str, Any]) -> Dict[str, Any]:
        """Evaluate machine learning models"""
        try:
            self.logger.info("Starting model evaluation")
            
            evaluation_results = {}
            
            # Classification evaluation
            if "classification" in config:
                evaluation_results.update(
                    self._evaluate_classification_models(df, models, config["classification"])
                )
            
            # Regression evaluation
            if "regression" in config:
                evaluation_results.update(
                    self._evaluate_regression_models(df, models, config["regression"])
                )
            
            # Clustering evaluation
            if "clustering" in config:
                evaluation_results.update(
                    self._evaluate_clustering_models(df, models, config["clustering"])
                )
            
            self.logger.info("Model evaluation completed")
            return evaluation_results
            
        except Exception as e:
            self.logger.error(f"Error in model evaluation: {str(e)}")
            raise
    
    def _apply_string_indexing(self, df: DataFrame, config: Dict[str, Any]) -> DataFrame:
        """Apply string indexing to categorical columns"""
        try:
            indexed_df = df
            columns = config.get("columns", [])
            
            for column in columns:
                indexer = StringIndexer(
                    inputCol=column,
                    outputCol=f"{column}_indexed",
                    handleInvalid="keep"
                )
                indexed_df = indexer.fit(indexed_df).transform(indexed_df)
            
            return indexed_df
            
        except Exception as e:
            self.logger.error(f"Error in string indexing: {str(e)}")
            raise
    
    def _apply_one_hot_encoding(self, df: DataFrame, config: Dict[str, Any]) -> DataFrame:
        """Apply one-hot encoding to indexed columns"""
        try:
            encoded_df = df
            columns = config.get("columns", [])
            
            for column in columns:
                encoder = OneHotEncoder(
                    inputCol=f"{column}_indexed",
                    outputCol=f"{column}_encoded",
                    dropLast=config.get("drop_last", True)
                )
                encoded_df = encoder.transform(encoded_df)
            
            return encoded_df
            
        except Exception as e:
            self.logger.error(f"Error in one-hot encoding: {str(e)}")
            raise
    
    def _apply_vector_assembly(self, df: DataFrame, config: Dict[str, Any]) -> DataFrame:
        """Apply vector assembly to feature columns"""
        try:
            feature_columns = config.get("feature_columns", [])
            output_col = config.get("output_col", "features")
            
            assembler = VectorAssembler(
                inputCols=feature_columns,
                outputCol=output_col,
                handleInvalid="skip"
            )
            
            return assembler.transform(df)
            
        except Exception as e:
            self.logger.error(f"Error in vector assembly: {str(e)}")
            raise
    
    def _apply_feature_scaling(self, df: DataFrame, config: Dict[str, Any]) -> DataFrame:
        """Apply feature scaling"""
        try:
            scaling_type = config.get("type", "standard")
            input_col = config.get("input_col", "features")
            output_col = config.get("output_col", "scaled_features")
            
            if scaling_type == "standard":
                scaler = StandardScaler(
                    inputCol=input_col,
                    outputCol=output_col,
                    withStd=True,
                    withMean=True
                )
            elif scaling_type == "minmax":
                scaler = MinMaxScaler(
                    inputCol=input_col,
                    outputCol=output_col,
                    min=0.0,
                    max=1.0
                )
            else:
                raise ValueError(f"Unsupported scaling type: {scaling_type}")
            
            return scaler.fit(df).transform(df)
            
        except Exception as e:
            self.logger.error(f"Error in feature scaling: {str(e)}")
            raise
    
    def _apply_pca(self, df: DataFrame, config: Dict[str, Any]) -> DataFrame:
        """Apply Principal Component Analysis"""
        try:
            input_col = config.get("input_col", "features")
            output_col = config.get("output_col", "pca_features")
            k = config.get("k", 10)
            
            pca = PCA(
                inputCol=input_col,
                outputCol=output_col,
                k=k
            )
            
            return pca.fit(df).transform(df)
            
        except Exception as e:
            self.logger.error(f"Error in PCA: {str(e)}")
            raise
    
    def _train_classification_models(self, df: DataFrame, config: Dict[str, Any]) -> Dict[str, Any]:
        """Train classification models"""
        try:
            models = {}
            target_column = config.get("target_column")
            feature_column = config.get("feature_column", "features")
            
            # Random Forest Classifier
            if "random_forest" in config:
                rf_config = config["random_forest"]
                rf = RandomForestClassifier(
                    featuresCol=feature_column,
                    labelCol=target_column,
                    numTrees=rf_config.get("num_trees", 100),
                    maxDepth=rf_config.get("max_depth", 5),
                    seed=42
                )
                models["random_forest_classifier"] = rf.fit(df)
            
            # Logistic Regression
            if "logistic_regression" in config:
                lr_config = config["logistic_regression"]
                lr = LogisticRegression(
                    featuresCol=feature_column,
                    labelCol=target_column,
                    maxIter=lr_config.get("max_iter", 100),
                    regParam=lr_config.get("reg_param", 0.0)
                )
                models["logistic_regression"] = lr.fit(df)
            
            # Gradient Boosting Classifier
            if "gradient_boosting" in config:
                gb_config = config["gradient_boosting"]
                gb = GBTClassifier(
                    featuresCol=feature_column,
                    labelCol=target_column,
                    maxIter=gb_config.get("max_iter", 100),
                    maxDepth=gb_config.get("max_depth", 5)
                )
                models["gradient_boosting_classifier"] = gb.fit(df)
            
            return models
            
        except Exception as e:
            self.logger.error(f"Error in classification model training: {str(e)}")
            raise
    
    def _train_regression_models(self, df: DataFrame, config: Dict[str, Any]) -> Dict[str, Any]:
        """Train regression models"""
        try:
            models = {}
            target_column = config.get("target_column")
            feature_column = config.get("feature_column", "features")
            
            # Random Forest Regressor
            if "random_forest" in config:
                rf_config = config["random_forest"]
                rf = RandomForestRegressor(
                    featuresCol=feature_column,
                    labelCol=target_column,
                    numTrees=rf_config.get("num_trees", 100),
                    maxDepth=rf_config.get("max_depth", 5),
                    seed=42
                )
                models["random_forest_regressor"] = rf.fit(df)
            
            # Linear Regression
            if "linear_regression" in config:
                lr_config = config["linear_regression"]
                lr = LinearRegression(
                    featuresCol=feature_column,
                    labelCol=target_column,
                    maxIter=lr_config.get("max_iter", 100),
                    regParam=lr_config.get("reg_param", 0.0)
                )
                models["linear_regression"] = lr.fit(df)
            
            # Gradient Boosting Regressor
            if "gradient_boosting" in config:
                gb_config = config["gradient_boosting"]
                gb = GBTRegressor(
                    featuresCol=feature_column,
                    labelCol=target_column,
                    maxIter=gb_config.get("max_iter", 100),
                    maxDepth=gb_config.get("max_depth", 5)
                )
                models["gradient_boosting_regressor"] = gb.fit(df)
            
            return models
            
        except Exception as e:
            self.logger.error(f"Error in regression model training: {str(e)}")
            raise
    
    def _train_clustering_models(self, df: DataFrame, config: Dict[str, Any]) -> Dict[str, Any]:
        """Train clustering models"""
        try:
            models = {}
            feature_column = config.get("feature_column", "features")
            
            # K-Means
            if "kmeans" in config:
                kmeans_config = config["kmeans"]
                kmeans = KMeans(
                    featuresCol=feature_column,
                    k=kmeans_config.get("k", 3),
                    maxIter=kmeans_config.get("max_iter", 20),
                    seed=42
                )
                models["kmeans"] = kmeans.fit(df)
            
            # Bisecting K-Means
            if "bisecting_kmeans" in config:
                bkmeans_config = config["bisecting_kmeans"]
                bkmeans = BisectingKMeans(
                    featuresCol=feature_column,
                    k=bkmeans_config.get("k", 3),
                    maxIter=bkmeans_config.get("max_iter", 20),
                    seed=42
                )
                models["bisecting_kmeans"] = bkmeans.fit(df)
            
            return models
            
        except Exception as e:
            self.logger.error(f"Error in clustering model training: {str(e)}")
            raise
    
    def _evaluate_classification_models(self, df: DataFrame, models: Dict[str, Any], config: Dict[str, Any]) -> Dict[str, Any]:
        """Evaluate classification models"""
        try:
            evaluation_results = {}
            target_column = config.get("target_column")
            prediction_column = config.get("prediction_column", "prediction")
            
            # Multiclass classification evaluator
            multiclass_evaluator = MulticlassClassificationEvaluator(
                labelCol=target_column,
                predictionCol=prediction_column
            )
            
            # Binary classification evaluator
            binary_evaluator = BinaryClassificationEvaluator(
                labelCol=target_column,
                rawPredictionCol="rawPrediction"
            )
            
            for model_name, model in models.items():
                if "classifier" in model_name:
                    # Make predictions
                    predictions = model.transform(df)
                    
                    # Calculate metrics
                    accuracy = multiclass_evaluator.setMetricName("accuracy").evaluate(predictions)
                    f1_score = multiclass_evaluator.setMetricName("f1").evaluate(predictions)
                    precision = multiclass_evaluator.setMetricName("weightedPrecision").evaluate(predictions)
                    recall = multiclass_evaluator.setMetricName("weightedRecall").evaluate(predictions)
                    
                    evaluation_results[f"{model_name}_accuracy"] = accuracy
                    evaluation_results[f"{model_name}_f1"] = f1_score
                    evaluation_results[f"{model_name}_precision"] = precision
                    evaluation_results[f"{model_name}_recall"] = recall
            
            return evaluation_results
            
        except Exception as e:
            self.logger.error(f"Error in classification model evaluation: {str(e)}")
            raise
    
    def _evaluate_regression_models(self, df: DataFrame, models: Dict[str, Any], config: Dict[str, Any]) -> Dict[str, Any]:
        """Evaluate regression models"""
        try:
            evaluation_results = {}
            target_column = config.get("target_column")
            prediction_column = config.get("prediction_column", "prediction")
            
            # Regression evaluator
            evaluator = RegressionEvaluator(
                labelCol=target_column,
                predictionCol=prediction_column
            )
            
            for model_name, model in models.items():
                if "regressor" in model_name or "regression" in model_name:
                    # Make predictions
                    predictions = model.transform(df)
                    
                    # Calculate metrics
                    rmse = evaluator.setMetricName("rmse").evaluate(predictions)
                    mae = evaluator.setMetricName("mae").evaluate(predictions)
                    r2_score = evaluator.setMetricName("r2").evaluate(predictions)
                    
                    evaluation_results[f"{model_name}_rmse"] = rmse
                    evaluation_results[f"{model_name}_mae"] = mae
                    evaluation_results[f"{model_name}_r2"] = r2_score
            
            return evaluation_results
            
        except Exception as e:
            self.logger.error(f"Error in regression model evaluation: {str(e)}")
            raise
    
    def _evaluate_clustering_models(self, df: DataFrame, models: Dict[str, Any], config: Dict[str, Any]) -> Dict[str, Any]:
        """Evaluate clustering models"""
        try:
            evaluation_results = {}
            feature_column = config.get("feature_column", "features")
            prediction_column = config.get("prediction_column", "prediction")
            
            # Clustering evaluator
            evaluator = ClusteringEvaluator(
                featuresCol=feature_column,
                predictionCol=prediction_column
            )
            
            for model_name, model in models.items():
                if "kmeans" in model_name:
                    # Make predictions
                    predictions = model.transform(df)
                    
                    # Calculate silhouette score
                    silhouette_score = evaluator.evaluate(predictions)
                    evaluation_results[f"{model_name}_silhouette"] = silhouette_score
            
            return evaluation_results
            
        except Exception as e:
            self.logger.error(f"Error in clustering model evaluation: {str(e)}")
            raise

# Architecture 2: AWS Glue ETL Pipeline

## Overview
This architecture implements a fully managed ETL pipeline using AWS Glue for data processing, with built-in data catalog, schema discovery, and Spark-based transformations.

## Components
- **Data Sources**: S3, RDS, Redshift, DynamoDB
- **ETL Engine**: AWS Glue (Apache Spark)
- **Data Catalog**: AWS Glue Data Catalog
- **Orchestration**: AWS Glue Workflows
- **Storage**: S3 Data Lake → Redshift/Athena
- **Monitoring**: Glue job metrics and CloudWatch

## Architecture Flow
1. Glue Crawler discovers and catalogs data sources
2. Glue ETL job extracts data using Spark
3. Built-in or custom transformations applied
4. Data quality checks and validation
5. Cleaned data loaded to target warehouse
6. Automatic schema evolution handling

## Benefits
- Fully managed Spark environment
- Built-in data catalog and schema discovery
- Handles large datasets efficiently
- Visual ETL development interface
- Automatic scaling

## Use Cases
- Large data volumes (GB to TB)
- Complex transformations
- Data lake architectures
- Schema evolution requirements

## Deployment
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Cost Estimation
- Glue Jobs: ~$0.44 per DPU-hour
- Glue Crawlers: ~$0.44 per DPU-hour
- Data Catalog: ~$1.00 per 100,000 requests
- S3: ~$0.023 per GB stored

## Monitoring
- Glue job execution metrics
- Data catalog statistics
- S3 storage and request metrics
- CloudWatch dashboards for pipeline health

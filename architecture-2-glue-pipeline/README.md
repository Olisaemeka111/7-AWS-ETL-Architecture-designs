# Architecture 2: AWS Glue ETL Pipeline

## Overview
This architecture implements a fully managed ETL pipeline using AWS Glue for data processing, with built-in data catalog, schema discovery, and Spark-based transformations.

## 🏗️ Architecture Components
- **Data Sources**: S3, RDS, Redshift, DynamoDB
- **ETL Engine**: AWS Glue (Apache Spark)
- **Data Catalog**: AWS Glue Data Catalog
- **Orchestration**: AWS Glue Workflows
- **Storage**: S3 Data Lake → Redshift/Athena
- **Monitoring**: Glue job metrics and CloudWatch

## 🔄 Data Flow
1. Glue Crawler discovers and catalogs data sources
2. Glue ETL job extracts data using Spark
3. Built-in or custom transformations applied
4. Data quality checks and validation
5. Cleaned data loaded to target warehouse
6. Automatic schema evolution handling

## ✅ Benefits
- Fully managed Spark environment
- Built-in data catalog and schema discovery
- Handles large datasets efficiently
- Visual ETL development interface
- Automatic scaling

## 🎯 Use Cases
- Large data volumes (GB to TB)
- Complex transformations
- Data lake architectures
- Schema evolution requirements

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured
- Terraform >= 1.0
- Python 3.9+

### Deployment
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Upload Glue Job Scripts
```bash
# Upload extract job script
aws s3 cp src/glue/extract_job.py s3://your-logs-bucket/scripts/

# Upload transform job script
aws s3 cp src/glue/transform_job.py s3://your-logs-bucket/scripts/

# Upload load job script
aws s3 cp src/glue/load_job.py s3://your-logs-bucket/scripts/
```

## 💰 Cost Estimation
- **Glue Jobs**: ~$0.44 per DPU-hour
- **Glue Crawlers**: ~$0.44 per DPU-hour
- **Data Catalog**: ~$1.00 per 100,000 requests
- **S3**: ~$0.023 per GB stored
- **Total**: ~$200-400/month (depending on data volume)

## 📊 Monitoring
- Glue job execution metrics
- Data catalog statistics
- S3 storage and request metrics
- CloudWatch dashboards for pipeline health

## 📁 Project Structure
```
architecture-2-glue-pipeline/
├── README.md
├── diagrams/
│   └── architecture-overview.md
├── docs/
│   └── deployment-guide.md
├── src/
│   └── glue/
│       ├── extract_job.py
│       ├── transform_job.py
│       └── load_job.py
└── terraform/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── modules/
        └── glue/
```

## 🔧 Configuration
See [deployment-guide.md](docs/deployment-guide.md) for detailed configuration instructions.

## 🧪 Testing
```bash
# Test extract job
aws glue start-job-run \
  --job-name "etl-glue-pipeline-dev-extract-job"

# Test transform job
aws glue start-job-run \
  --job-name "etl-glue-pipeline-dev-transform-job"

# Test load job
aws glue start-job-run \
  --job-name "etl-glue-pipeline-dev-load-job"
```

## 🔒 Security
- IAM roles with least privilege
- VPC endpoints for private communication
- Encryption at rest and in transit
- Glue security configurations

## 📈 Performance Optimization
- Right-size DPU allocation
- Use job bookmarks to avoid reprocessing
- Implement incremental processing
- Monitor and optimize job performance
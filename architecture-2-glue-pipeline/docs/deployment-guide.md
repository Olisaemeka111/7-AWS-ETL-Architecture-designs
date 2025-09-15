# Architecture 2: AWS Glue ETL Pipeline - Deployment Guide

## Prerequisites

### AWS Account Setup
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Python 3.9+ for Glue job development
- Access to AWS services: Glue, S3, Redshift, VPC, IAM, CloudWatch

### Required IAM Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "glue:*",
                "s3:*",
                "redshift:*",
                "vpc:*",
                "iam:*",
                "cloudwatch:*",
                "logs:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## Deployment Steps

### 1. Clone and Setup
```bash
cd architecture-2-glue-pipeline
```

### 2. Configure Variables
Edit `terraform/variables.tf` with your specific values:
```hcl
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "etl-glue-pipeline"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
```

### 3. Initialize Terraform
```bash
cd terraform
terraform init
```

### 4. Plan Deployment
```bash
terraform plan -var-file="terraform.tfvars"
```

### 5. Deploy Infrastructure
```bash
terraform apply -var-file="terraform.tfvars"
```

### 6. Upload Glue Job Scripts
```bash
# Upload extract job script
aws s3 cp src/glue/extract_job.py s3://your-logs-bucket/scripts/

# Upload transform job script
aws s3 cp src/glue/transform_job.py s3://your-logs-bucket/scripts/

# Upload load job script
aws s3 cp src/glue/load_job.py s3://your-logs-bucket/scripts/
```

## Configuration

### Glue Job Parameters
Update job parameters in Terraform configuration:

```hcl
glue_jobs = {
  "extract-job" = {
    name         = "etl-glue-pipeline-dev-extract-job"
    script_path  = "s3://your-logs-bucket/scripts/extract_job.py"
    max_capacity = 2
    timeout      = 60
    glue_version = "4.0"
  }
  "transform-job" = {
    name         = "etl-glue-pipeline-dev-transform-job"
    script_path  = "s3://your-logs-bucket/scripts/transform_job.py"
    max_capacity = 4
    timeout      = 120
    glue_version = "4.0"
  }
  "load-job" = {
    name         = "etl-glue-pipeline-dev-load-job"
    script_path  = "s3://your-logs-bucket/scripts/load_job.py"
    max_capacity = 3
    timeout      = 90
    glue_version = "4.0"
  }
}
```

### Data Source Configuration
Configure data sources in `terraform/variables.tf`:

```hcl
variable "source_databases" {
  description = "List of source databases to connect to"
  type = list(object({
    name        = string
    type        = string
    host        = string
    port        = number
    database    = string
    username    = string
    password    = string
    description = string
  }))
  default = [
    {
      name        = "production-db"
      type        = "mysql"
      host        = "your-db-host.amazonaws.com"
      port        = 3306
      database    = "production"
      username    = "glue_user"
      password    = "your-password"
      description = "Production MySQL database"
    }
  ]
}
```

### S3 Data Lake Structure
The deployment creates the following S3 bucket structure:

```
etl-glue-pipeline-dev-raw-zone/
├── sources/
│   ├── legislators/
│   │   └── extract_date=2024-01-01/
│   └── sample_sales/
│       └── extract_date=2024-01-01/

etl-glue-pipeline-dev-clean-zone/
├── tables/
│   ├── legislators_clean/
│   │   └── extract_date=2024-01-01/
│   └── sample_sales_clean/
│       └── extract_date=2024-01-01/
└── quality_reports/
    ├── legislators/
    └── sample_sales/

etl-glue-pipeline-dev-aggregated-zone/
├── aggregations/
│   ├── legislators/
│   │   ├── state_aggregations/
│   │   ├── party_aggregations/
│   │   └── gender_distribution/
│   └── sample_sales/
│       ├── regional_sales/
│       ├── category_sales/
│       └── daily_sales/
└── summary_reports/
    ├── legislators/
    └── sample_sales/
```

## Testing

### 1. Test Individual Glue Jobs
```bash
# Test extract job
aws glue start-job-run \
  --job-name "etl-glue-pipeline-dev-extract-job" \
  --arguments '{"--RAW_ZONE_BUCKET":"etl-glue-pipeline-dev-raw-zone","--CLEAN_ZONE_BUCKET":"etl-glue-pipeline-dev-clean-zone","--TEMP_ZONE_BUCKET":"etl-glue-pipeline-dev-temp-zone"}'

# Test transform job
aws glue start-job-run \
  --job-name "etl-glue-pipeline-dev-transform-job" \
  --arguments '{"--RAW_ZONE_BUCKET":"etl-glue-pipeline-dev-raw-zone","--CLEAN_ZONE_BUCKET":"etl-glue-pipeline-dev-clean-zone","--TEMP_ZONE_BUCKET":"etl-glue-pipeline-dev-temp-zone"}'

# Test load job
aws glue start-job-run \
  --job-name "etl-glue-pipeline-dev-load-job" \
  --arguments '{"--CLEAN_ZONE_BUCKET":"etl-glue-pipeline-dev-clean-zone","--AGGREGATED_ZONE_BUCKET":"etl-glue-pipeline-dev-aggregated-zone","--TEMP_ZONE_BUCKET":"etl-glue-pipeline-dev-temp-zone"}'
```

### 2. Test Glue Crawlers
```bash
# Start source crawler
aws glue start-crawler \
  --name "etl-glue-pipeline-dev-source-crawler"

# Check crawler status
aws glue get-crawler \
  --name "etl-glue-pipeline-dev-source-crawler"
```

### 3. Test End-to-End Workflow
```bash
# Start the main workflow
aws glue start-workflow-run \
  --name "etl-glue-pipeline-dev-main-workflow"
```

## Monitoring Setup

### 1. CloudWatch Dashboard
```bash
# Create dashboard
aws cloudwatch put-dashboard \
  --dashboard-name "Glue-ETL-Pipeline-Monitoring" \
  --dashboard-body file://monitoring/cloudwatch-dashboard.json
```

### 2. Glue Job Monitoring
```bash
# Monitor job runs
aws glue get-job-runs \
  --job-name "etl-glue-pipeline-dev-extract-job" \
  --max-items 10

# Get job run details
aws glue get-job-run \
  --job-name "etl-glue-pipeline-dev-extract-job" \
  --run-id "jr_1234567890"
```

### 3. Data Catalog Monitoring
```bash
# List databases
aws glue get-databases

# List tables in database
aws glue get-tables \
  --database-name "etl_glue_pipeline_dev_source_db"

# Get table details
aws glue get-table \
  --database-name "etl_glue_pipeline_dev_source_db" \
  --name "legislators_raw"
```

## Troubleshooting

### Common Issues

#### 1. Glue Job Failures
**Symptoms:**
- Job runs fail with errors
- Spark application errors
- Memory or timeout issues

**Solutions:**
```bash
# Check job run logs
aws logs get-log-events \
  --log-group-name "/aws-glue/jobs/logs-v2" \
  --log-stream-name "etl-glue-pipeline-dev-extract-job"

# Increase DPU allocation
aws glue update-job \
  --job-name "etl-glue-pipeline-dev-extract-job" \
  --job-update '{"MaxCapacity": 4}'

# Increase timeout
aws glue update-job \
  --job-name "etl-glue-pipeline-dev-extract-job" \
  --job-update '{"Timeout": 120}'
```

#### 2. S3 Access Issues
**Symptoms:**
- Access denied errors
- Bucket not found errors
- Permission issues

**Solutions:**
```bash
# Check S3 bucket policy
aws s3api get-bucket-policy \
  --bucket "etl-glue-pipeline-dev-raw-zone"

# Update bucket policy
aws s3api put-bucket-policy \
  --bucket "etl-glue-pipeline-dev-raw-zone" \
  --policy file://s3-bucket-policy.json
```

#### 3. Crawler Issues
**Symptoms:**
- Crawler fails to discover data
- Schema detection issues
- Connection problems

**Solutions:**
```bash
# Check crawler logs
aws logs get-log-events \
  --log-group-name "/aws-glue/crawlers" \
  --log-stream-name "etl-glue-pipeline-dev-source-crawler"

# Update crawler configuration
aws glue update-crawler \
  --name "etl-glue-pipeline-dev-source-crawler" \
  --targets '{"S3Targets": [{"Path": "s3://etl-glue-pipeline-dev-raw-zone/sources/"}]}'
```

### Debugging Steps

1. **Check Glue Job Logs**
   ```bash
   # Get job run logs
   aws glue get-job-run \
     --job-name "your-job-name" \
     --run-id "your-run-id"
   ```

2. **Monitor Spark UI**
   - Enable Spark UI in job parameters
   - Access via Glue console or CloudWatch logs

3. **Check Data Catalog**
   ```bash
   # Verify tables are created
   aws glue get-tables \
     --database-name "your-database"
   ```

4. **Validate S3 Data**
   ```bash
   # Check S3 data structure
   aws s3 ls s3://your-bucket/ --recursive
   ```

## Performance Optimization

### 1. DPU Optimization
```python
# Optimize DPU allocation based on data volume
def calculate_optimal_dpu(data_size_gb):
    if data_size_gb < 1:
        return 2
    elif data_size_gb < 10:
        return 4
    elif data_size_gb < 100:
        return 8
    else:
        return 16
```

### 2. Spark Configuration
```python
# Optimize Spark settings in Glue jobs
spark_conf = {
    'spark.sql.adaptive.enabled': 'true',
    'spark.sql.adaptive.coalescePartitions.enabled': 'true',
    'spark.sql.adaptive.skewJoin.enabled': 'true',
    'spark.serializer': 'org.apache.spark.serializer.KryoSerializer',
    'spark.sql.parquet.compression.codec': 'snappy'
}
```

### 3. Data Partitioning
```python
# Optimize data partitioning
def optimize_partitioning(df, partition_columns):
    return df.repartition(*partition_columns) \
             .write \
             .mode('overwrite') \
             .partitionBy(partition_columns) \
             .parquet(output_path)
```

## Security Configuration

### 1. IAM Roles
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::etl-glue-pipeline-dev-*",
                "arn:aws:s3:::etl-glue-pipeline-dev-*/*"
            ]
        }
    ]
}
```

### 2. VPC Configuration
- Deploy Glue jobs in private subnets
- Use VPC endpoints for S3 access
- Configure security groups for database access

### 3. Encryption
```bash
# Enable encryption for Glue security configuration
aws glue create-security-configuration \
  --name "etl-glue-pipeline-dev-security-config" \
  --encryption-configuration '{
    "S3Encryption": [{"S3EncryptionMode": "SSE-KMS", "KmsKeyArn": "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"}],
    "CloudWatchEncryption": [{"CloudWatchEncryptionMode": "SSE-KMS", "KmsKeyArn": "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"}],
    "JobBookmarksEncryption": [{"JobBookmarksEncryptionMode": "CSE-KMS", "KmsKeyArn": "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"}]
  }'
```

## Maintenance

### 1. Regular Tasks
- Monitor job performance and costs
- Update Glue job scripts
- Review and optimize DPU allocation
- Clean up temporary data

### 2. Backup Strategy
- Regular S3 bucket backups
- Glue Data Catalog backups
- Terraform state backups

### 3. Scaling Considerations
- Monitor data volume growth
- Adjust DPU allocation as needed
- Consider moving to larger Redshift nodes
- Implement auto-scaling for high-volume periods

## Cost Optimization

### 1. DPU Management
- Right-size DPU allocation
- Use job bookmarks to avoid reprocessing
- Implement incremental processing
- Monitor and optimize job performance

### 2. Storage Optimization
- Use appropriate S3 storage classes
- Implement lifecycle policies
- Compress data with efficient formats
- Partition data for query optimization

### 3. Scheduling Optimization
- Run jobs during off-peak hours
- Batch multiple operations
- Use spot instances for non-critical jobs
- Implement cost-aware scheduling

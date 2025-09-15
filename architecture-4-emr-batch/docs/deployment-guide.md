# Architecture 4: EMR Batch ETL - Deployment Guide

## Prerequisites

### AWS Account Setup
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Python 3.9+ for Spark applications
- Access to AWS services: EMR, S3, VPC, IAM, CloudWatch, Glue, Redshift

### Required IAM Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "emr:*",
                "s3:*",
                "vpc:*",
                "iam:*",
                "cloudwatch:*",
                "logs:*",
                "glue:*",
                "redshift:*",
                "application-autoscaling:*",
                "ec2:*",
                "elasticmapreduce:*"
            ],
            "Resource": "*"
        }
    ]
}
```

### Local Environment Setup
```bash
# Install Terraform
brew install terraform

# Install AWS CLI
brew install awscli

# Configure AWS CLI
aws configure

# Verify installation
terraform version
aws --version
```

## Deployment Steps

### 1. Clone and Navigate to Architecture 4
```bash
cd architecture-4-emr-batch
```

### 2. Configure Variables
Create a `terraform.tfvars` file:
```hcl
# General Configuration
project_name = "emr-batch-etl"
environment  = "dev"
aws_region   = "us-east-1"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"

# EMR Cluster Configuration
master_instance_type = "m5.xlarge"
core_instance_type   = "m5.large"
core_instance_count  = 2
task_instance_type   = "m5.large"
task_instance_count  = 0

# Auto-scaling Configuration
enable_auto_scaling = true
min_capacity        = 0
max_capacity        = 20

# Spot Instance Configuration
enable_spot_instances = true
spot_bid_price        = "0.10"

# Redshift Configuration
enable_redshift = true
redshift_node_type = "dc2.large"
redshift_number_of_nodes = 1
redshift_database_name = "batch_warehouse"
redshift_master_username = "admin"
redshift_master_password = "YourSecurePassword123!"

# Airflow Configuration (Optional)
enable_airflow = false

# Monitoring Configuration
enable_detailed_monitoring = true
log_retention_days = 14

# Security Configuration
enable_encryption = true
```

### 3. Initialize Terraform
```bash
cd terraform
terraform init
```

### 4. Plan Deployment
```bash
terraform plan -var-file="../terraform.tfvars"
```

### 5. Deploy Infrastructure
```bash
terraform apply -var-file="../terraform.tfvars"
```

### 6. Verify Deployment
```bash
# Check EMR cluster status
aws emr list-clusters --active

# Check S3 buckets
aws s3 ls

# Check VPC
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=emr-batch-etl"
```

## Post-Deployment Configuration

### 1. Upload Spark Applications
```bash
# Upload data processing job
aws s3 cp src/spark/data_processing_job.py s3://your-logs-bucket/scripts/

# Upload ML pipeline
aws s3 cp src/spark/ml_pipeline.py s3://your-logs-bucket/scripts/

# Upload configuration files
aws s3 cp config/emr_batch_config.json s3://your-logs-bucket/config/
```

### 2. Configure EMR Steps
```bash
# Submit Spark job to EMR cluster
aws emr add-steps \
    --cluster-id j-XXXXXXXXXX \
    --steps Type=Spark,Name="Data Processing Job",ActionOnFailure=CONTINUE,Args=[--class,org.apache.spark.deploy.SparkSubmit,--master,yarn,--deploy-mode,cluster,s3://your-logs-bucket/scripts/data_processing_job.py,s3://your-logs-bucket/config/emr_batch_config.json]
```

### 3. Set Up Monitoring
```bash
# Create CloudWatch dashboard
aws cloudwatch put-dashboard \
    --dashboard-name "EMR-Batch-ETL-Dashboard" \
    --dashboard-body file://monitoring/cloudwatch-dashboard.json

# Set up CloudWatch alarms
aws cloudwatch put-metric-alarm \
    --alarm-name "EMR-Cluster-Node-Failure" \
    --alarm-description "Alert when EMR cluster nodes fail" \
    --metric-name "IsIdle" \
    --namespace "AWS/ElasticMapReduce" \
    --statistic "Average" \
    --period 300 \
    --threshold 0 \
    --comparison-operator "LessThanThreshold" \
    --evaluation-periods 2
```

## Data Processing Workflow

### 1. Data Ingestion
```python
# Example: Ingest data from S3
spark.read.parquet("s3://your-raw-data-bucket/")
```

### 2. Data Transformation
```python
# Example: Apply transformations
transformed_df = df \
    .filter(col("status") == "active") \
    .withColumn("processed_date", current_timestamp()) \
    .groupBy("category") \
    .agg(sum("amount").alias("total_amount"))
```

### 3. Data Loading
```python
# Example: Load to Redshift
transformed_df.write \
    .format("jdbc") \
    .option("url", "jdbc:redshift://your-cluster.region.redshift.amazonaws.com:5439/warehouse") \
    .option("dbtable", "processed_data") \
    .option("user", "admin") \
    .option("password", "password") \
    .mode("overwrite") \
    .save()
```

## Monitoring and Troubleshooting

### 1. EMR Cluster Monitoring
```bash
# Check cluster status
aws emr describe-cluster --cluster-id j-XXXXXXXXXX

# List cluster steps
aws emr list-steps --cluster-id j-XXXXXXXXXX

# Get step details
aws emr describe-step --cluster-id j-XXXXXXXXXX --step-id s-XXXXXXXXXX
```

### 2. CloudWatch Logs
```bash
# View EMR logs
aws logs describe-log-groups --log-group-name-prefix "/aws/emr"

# Get log events
aws logs get-log-events \
    --log-group-name "/aws/emr/j-XXXXXXXXXX" \
    --log-stream-name "spark/spark-application-XXXXXXXXXX"
```

### 3. Spark UI Access
```bash
# Get master node public DNS
aws emr describe-cluster --cluster-id j-XXXXXXXXXX \
    --query 'Cluster.MasterPublicDnsName' --output text

# Access Spark UI (replace with actual DNS)
# http://ec2-XX-XX-XX-XX.compute-1.amazonaws.com:4040
```

## Cost Optimization

### 1. Spot Instances
```bash
# Configure spot instances for task nodes
aws emr modify-instance-groups \
    --cluster-id j-XXXXXXXXXX \
    --instance-groups InstanceGroupId=ig-XXXXXXXXXX,InstanceCount=5,Market=SPOT,BidPrice=0.10
```

### 2. Auto-scaling
```bash
# Enable auto-scaling
aws emr put-auto-scaling-policy \
    --cluster-id j-XXXXXXXXXX \
    --instance-group-id ig-XXXXXXXXXX \
    --auto-scaling-policy MinCapacity=0,MaxCapacity=20,TargetCapacity=5
```

### 3. Cluster Termination
```bash
# Terminate cluster after job completion
aws emr terminate-clusters --cluster-ids j-XXXXXXXXXX
```

## Security Best Practices

### 1. VPC Configuration
- Deploy EMR cluster in private subnets
- Use VPC endpoints for S3 access
- Configure security groups for network isolation

### 2. IAM Roles
- Use least privilege principle
- Separate roles for different components
- Enable MFA for administrative access

### 3. Data Encryption
- Enable encryption at rest for S3 buckets
- Use KMS keys for encryption
- Enable encryption in transit

## Performance Tuning

### 1. Spark Configuration
```python
# Optimize Spark for EMR
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
spark.conf.set("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
```

### 2. Data Partitioning
```python
# Partition data for better performance
df.write \
    .partitionBy("year", "month", "day") \
    .parquet("s3://your-bucket/partitioned-data/")
```

### 3. Caching
```python
# Cache frequently used DataFrames
df.cache()
df.persist(StorageLevel.MEMORY_AND_DISK_SER)
```

## Troubleshooting Common Issues

### 1. Cluster Launch Failures
```bash
# Check cluster logs
aws logs describe-log-groups --log-group-name-prefix "/aws/emr"

# Common causes:
# - Insufficient IAM permissions
# - VPC configuration issues
# - Security group rules
# - Subnet availability
```

### 2. Job Failures
```bash
# Check step logs
aws emr describe-step --cluster-id j-XXXXXXXXXX --step-id s-XXXXXXXXXX

# Common causes:
# - Memory issues
# - Data format problems
# - Network connectivity
# - Resource constraints
```

### 3. Performance Issues
```bash
# Monitor cluster metrics
aws cloudwatch get-metric-statistics \
    --namespace "AWS/ElasticMapReduce" \
    --metric-name "IsIdle" \
    --dimensions Name=JobFlowId,Value=j-XXXXXXXXXX \
    --start-time 2023-01-01T00:00:00Z \
    --end-time 2023-01-01T23:59:59Z \
    --period 300 \
    --statistics Average
```

## Cleanup

### 1. Terminate EMR Cluster
```bash
aws emr terminate-clusters --cluster-ids j-XXXXXXXXXX
```

### 2. Destroy Terraform Infrastructure
```bash
cd terraform
terraform destroy -var-file="../terraform.tfvars"
```

### 3. Clean Up S3 Buckets
```bash
# Empty buckets before deletion
aws s3 rm s3://your-bucket --recursive

# Delete buckets
aws s3 rb s3://your-bucket
```

## Next Steps

1. **Data Pipeline Setup**: Configure data sources and destinations
2. **Job Scheduling**: Set up Airflow or Step Functions for orchestration
3. **Monitoring**: Configure alerts and dashboards
4. **Cost Optimization**: Implement spot instances and auto-scaling
5. **Security**: Review and enhance security configurations
6. **Performance**: Optimize Spark configurations and data partitioning

## Support and Resources

- **AWS EMR Documentation**: https://docs.aws.amazon.com/emr/
- **Apache Spark Documentation**: https://spark.apache.org/docs/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest
- **AWS Support**: https://aws.amazon.com/support/

For additional help, refer to the troubleshooting guide and performance optimization documentation.

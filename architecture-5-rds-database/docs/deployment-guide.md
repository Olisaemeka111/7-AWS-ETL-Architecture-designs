# Architecture 5: RDS Database ETL - Deployment Guide

## Prerequisites

### AWS Account Setup
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Python 3.9+ for Lambda functions
- Access to AWS services: RDS, DMS, Lambda, S3, VPC, IAM, CloudWatch, Secrets Manager

### Required IAM Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds:*",
                "dms:*",
                "lambda:*",
                "s3:*",
                "vpc:*",
                "iam:*",
                "cloudwatch:*",
                "logs:*",
                "secretsmanager:*",
                "glue:*",
                "redshift:*",
                "events:*"
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

# Install PostgreSQL client (for testing)
brew install postgresql

# Configure AWS CLI
aws configure

# Verify installation
terraform version
aws --version
psql --version
```

## Deployment Steps

### 1. Clone and Navigate to Architecture 5
```bash
cd architecture-5-rds-database
```

### 2. Configure Variables
Create a `terraform.tfvars` file:
```hcl
# General Configuration
project_name = "rds-database-etl"
environment  = "dev"
aws_region   = "us-east-1"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"

# Source RDS Configuration
source_db_name = "sourcedb"
source_db_username = "admin"
source_db_password = "YourSecurePassword123!"
source_instance_class = "db.t3.micro"
source_allocated_storage = 20
source_engine = "postgres"
source_engine_version = "13.7"

# Target RDS Configuration
target_db_name = "targetdb"
target_db_username = "admin"
target_db_password = "YourSecurePassword123!"
target_instance_class = "db.t3.micro"
target_allocated_storage = 20
target_engine = "postgres"
target_engine_version = "13.7"

# Aurora Configuration (Optional)
enable_aurora = false

# DMS Configuration
dms_instance_class = "dms.t3.micro"
dms_allocated_storage = 50

# Redshift Configuration
enable_redshift = true
redshift_node_type = "dc2.large"
redshift_number_of_nodes = 1
redshift_database_name = "database_warehouse"
redshift_master_username = "admin"
redshift_master_password = "YourSecurePassword123!"

# ETL Configuration
etl_schedule_expression = "rate(1 hour)"

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
# Check RDS instances
aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address]' --output table

# Check DMS replication instance
aws dms describe-replication-instances --query 'ReplicationInstances[*].[ReplicationInstanceIdentifier,ReplicationInstanceStatus]' --output table

# Check Lambda functions
aws lambda list-functions --query 'Functions[*].[FunctionName,Runtime,LastModified]' --output table

# Check S3 buckets
aws s3 ls
```

## Post-Deployment Configuration

### 1. Set Up Database Secrets
```bash
# Create secrets for database passwords
aws secretsmanager create-secret \
    --name "source-db-password" \
    --description "Source database password" \
    --secret-string "YourSecurePassword123!"

aws secretsmanager create-secret \
    --name "target-db-password" \
    --description "Target database password" \
    --secret-string "YourSecurePassword123!"

aws secretsmanager create-secret \
    --name "redshift-password" \
    --description "Redshift password" \
    --secret-string "YourSecurePassword123!"
```

### 2. Create Database Tables
```bash
# Connect to source database
psql -h your-source-endpoint -p 5432 -U admin -d sourcedb

# Create sample tables
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    order_date DATE,
    total_amount DECIMAL(10,2),
    status VARCHAR(20)
);

# Insert sample data
INSERT INTO customers (first_name, last_name, email) VALUES
('John', 'Doe', 'john.doe@example.com'),
('Jane', 'Smith', 'jane.smith@example.com'),
('Bob', 'Johnson', 'bob.johnson@example.com');

INSERT INTO orders (customer_id, order_date, total_amount, status) VALUES
(1, '2023-01-15', 99.99, 'completed'),
(2, '2023-01-16', 149.50, 'pending'),
(3, '2023-01-17', 75.25, 'completed');

# Connect to target database
psql -h your-target-endpoint -p 5432 -U admin -d targetdb

# Create target tables
CREATE TABLE customers_clean (
    id INTEGER PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    processed_at TIMESTAMP
);

CREATE TABLE orders_clean (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER,
    order_date DATE,
    total_amount DECIMAL(10,2),
    status VARCHAR(20),
    processed_at TIMESTAMP
);
```

### 3. Configure DMS Replication Tasks
```bash
# Create DMS replication task
aws dms create-replication-task \
    --replication-task-identifier "full-load-and-cdc" \
    --source-endpoint-arn "arn:aws:dms:region:account:endpoint/source-endpoint" \
    --target-endpoint-arn "arn:aws:dms:region:account:endpoint/target-endpoint" \
    --replication-instance-arn "arn:aws:dms:region:account:rep:replication-instance" \
    --migration-type "full-load-and-cdc" \
    --table-mappings '{
        "rules": [
            {
                "rule-type": "selection",
                "rule-id": "1",
                "rule-name": "1",
                "object-locator": {
                    "schema-name": "public",
                    "table-name": "%"
                },
                "rule-action": "include"
            }
        ]
    }'
```

### 4. Upload Lambda Functions
```bash
# Create deployment package
cd src/lambda
zip -r etl_processor.zip etl_processor.py

# Upload to S3
aws s3 cp etl_processor.zip s3://your-logs-bucket/lambda-functions/

# Update Lambda function code
aws lambda update-function-code \
    --function-name "rds-database-etl-dev-etl-processor" \
    --s3-bucket "your-logs-bucket" \
    --s3-key "lambda-functions/etl_processor.zip"
```

### 5. Set Up EventBridge Rules
```bash
# Create ETL schedule rule
aws events put-rule \
    --name "rds-database-etl-dev-etl-schedule" \
    --schedule-expression "rate(1 hour)" \
    --description "Schedule ETL jobs"

# Add Lambda target
aws events put-targets \
    --rule "rds-database-etl-dev-etl-schedule" \
    --targets "Id"="1","Arn"="arn:aws:lambda:region:account:function:rds-database-etl-dev-etl-processor"
```

## Data Processing Workflow

### 1. Manual ETL Execution
```bash
# Invoke Lambda function manually
aws lambda invoke \
    --function-name "rds-database-etl-dev-etl-processor" \
    --payload '{
        "etl_config": {
            "extraction": {
                "table_name": "customers",
                "columns": "*",
                "where_clause": "created_at >= CURRENT_DATE - INTERVAL '\''1 day'\''"
            },
            "transformation": {
                "column_transformations": {
                    "first_name": {"type": "uppercase"},
                    "last_name": {"type": "uppercase"},
                    "email": {"type": "lowercase"}
                },
                "validation_rules": [
                    {"column": "email", "type": "not_null"},
                    {"column": "id", "type": "unique"}
                ]
            },
            "loading": {
                "table_name": "customers_clean",
                "mode": "upsert",
                "conflict_columns": ["id"],
                "batch_size": 1000
            },
            "s3_backup": {
                "bucket": "your-processed-data-bucket",
                "key": "customers/processed_customers.parquet",
                "format": "parquet"
            }
        }
    }' \
    response.json

# Check response
cat response.json
```

### 2. DMS Replication Monitoring
```bash
# Check replication task status
aws dms describe-replication-tasks \
    --query 'ReplicationTasks[*].[ReplicationTaskIdentifier,Status,ReplicationTaskStats]' \
    --output table

# Get replication task statistics
aws dms describe-replication-task-statistics \
    --replication-task-arn "arn:aws:dms:region:account:task:full-load-and-cdc"
```

### 3. Data Validation
```bash
# Connect to target database and validate data
psql -h your-target-endpoint -p 5432 -U admin -d targetdb

# Check record counts
SELECT COUNT(*) FROM customers_clean;
SELECT COUNT(*) FROM orders_clean;

# Check data quality
SELECT 
    COUNT(*) as total_records,
    COUNT(CASE WHEN email IS NOT NULL THEN 1 END) as non_null_emails,
    COUNT(CASE WHEN first_name = UPPER(first_name) THEN 1 END) as uppercase_names
FROM customers_clean;
```

## Monitoring and Troubleshooting

### 1. CloudWatch Monitoring
```bash
# View CloudWatch dashboard
aws cloudwatch get-dashboard --dashboard-name "RDS-Database-ETL-Dashboard"

# Check Lambda function logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/rds-database-etl"

# Get log events
aws logs get-log-events \
    --log-group-name "/aws/lambda/rds-database-etl-dev-etl-processor" \
    --log-stream-name "2023/01/15/[$LATEST]stream-id"
```

### 2. RDS Monitoring
```bash
# Check RDS instance status
aws rds describe-db-instances \
    --db-instance-identifier "rds-database-etl-dev-source-db" \
    --query 'DBInstances[0].[DBInstanceStatus,DBInstanceClass,AllocatedStorage]'

# Check RDS performance insights
aws rds describe-db-instances \
    --db-instance-identifier "rds-database-etl-dev-source-db" \
    --query 'DBInstances[0].PerformanceInsightsEnabled'
```

### 3. DMS Monitoring
```bash
# Check DMS replication instance metrics
aws cloudwatch get-metric-statistics \
    --namespace "AWS/DMS" \
    --metric-name "CPUUtilization" \
    --dimensions Name=ReplicationInstanceIdentifier,Value=rds-database-etl-dev-dms-instance \
    --start-time 2023-01-15T00:00:00Z \
    --end-time 2023-01-15T23:59:59Z \
    --period 300 \
    --statistics Average
```

## Performance Optimization

### 1. Database Optimization
```sql
-- Create indexes for better performance
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_order_date ON orders(order_date);

-- Analyze tables for query optimization
ANALYZE customers;
ANALYZE orders;
```

### 2. Lambda Optimization
```python
# Optimize Lambda function settings
# Increase memory for better performance
# Set appropriate timeout values
# Use connection pooling for database connections
```

### 3. DMS Optimization
```bash
# Optimize DMS replication instance
aws dms modify-replication-instance \
    --replication-instance-arn "arn:aws:dms:region:account:rep:replication-instance" \
    --replication-instance-class "dms.c5.large" \
    --allocated-storage 100
```

## Security Best Practices

### 1. Database Security
```bash
# Enable encryption at rest
aws rds modify-db-instance \
    --db-instance-identifier "rds-database-etl-dev-source-db" \
    --storage-encrypted

# Enable encryption in transit
aws rds modify-db-instance \
    --db-instance-identifier "rds-database-etl-dev-source-db" \
    --ca-certificate-identifier "rds-ca-2019"
```

### 2. Network Security
```bash
# Update security groups to restrict access
aws ec2 authorize-security-group-ingress \
    --group-id "sg-xxxxxxxxx" \
    --protocol tcp \
    --port 5432 \
    --cidr "10.0.0.0/16"
```

### 3. Secrets Management
```bash
# Rotate database passwords
aws secretsmanager update-secret \
    --secret-id "source-db-password" \
    --secret-string "NewSecurePassword123!"

# Enable automatic rotation
aws secretsmanager update-secret \
    --secret-id "source-db-password" \
    --description "Source database password with rotation" \
    --secret-string "NewSecurePassword123!"
```

## Cost Optimization

### 1. Instance Right-Sizing
```bash
# Monitor CPU and memory utilization
aws cloudwatch get-metric-statistics \
    --namespace "AWS/RDS" \
    --metric-name "CPUUtilization" \
    --dimensions Name=DBInstanceIdentifier,Value=rds-database-etl-dev-source-db \
    --start-time 2023-01-01T00:00:00Z \
    --end-time 2023-01-31T23:59:59Z \
    --period 3600 \
    --statistics Average

# Right-size based on metrics
aws rds modify-db-instance \
    --db-instance-identifier "rds-database-etl-dev-source-db" \
    --db-instance-class "db.t3.small"
```

### 2. Storage Optimization
```bash
# Enable storage autoscaling
aws rds modify-db-instance \
    --db-instance-identifier "rds-database-etl-dev-source-db" \
    --max-allocated-storage 1000
```

### 3. Backup Optimization
```bash
# Optimize backup retention
aws rds modify-db-instance \
    --db-instance-identifier "rds-database-etl-dev-source-db" \
    --backup-retention-period 7
```

## Troubleshooting Common Issues

### 1. Database Connection Issues
```bash
# Check security group rules
aws ec2 describe-security-groups \
    --group-ids "sg-xxxxxxxxx" \
    --query 'SecurityGroups[0].IpPermissions'

# Test database connectivity
psql -h your-endpoint -p 5432 -U admin -d sourcedb -c "SELECT 1;"
```

### 2. DMS Replication Issues
```bash
# Check replication task status
aws dms describe-replication-tasks \
    --replication-task-arn "arn:aws:dms:region:account:task:full-load-and-cdc"

# Check replication task logs
aws logs get-log-events \
    --log-group-name "/aws/dms/task/rds-database-etl-dev-dms-instance" \
    --log-stream-name "full-load-and-cdc"
```

### 3. Lambda Function Issues
```bash
# Check Lambda function logs
aws logs get-log-events \
    --log-group-name "/aws/lambda/rds-database-etl-dev-etl-processor" \
    --log-stream-name "2023/01/15/[$LATEST]stream-id"

# Test Lambda function
aws lambda invoke \
    --function-name "rds-database-etl-dev-etl-processor" \
    --payload '{"test": true}' \
    response.json
```

## Cleanup

### 1. Stop DMS Replication Tasks
```bash
aws dms stop-replication-task \
    --replication-task-arn "arn:aws:dms:region:account:task:full-load-and-cdc"
```

### 2. Destroy Terraform Infrastructure
```bash
cd terraform
terraform destroy -var-file="../terraform.tfvars"
```

### 3. Clean Up Secrets
```bash
aws secretsmanager delete-secret \
    --secret-id "source-db-password" \
    --force-delete-without-recovery

aws secretsmanager delete-secret \
    --secret-id "target-db-password" \
    --force-delete-without-recovery
```

## Next Steps

1. **Data Pipeline Setup**: Configure data sources and destinations
2. **Job Scheduling**: Set up EventBridge rules for orchestration
3. **Monitoring**: Configure alerts and dashboards
4. **Cost Optimization**: Implement right-sizing and backup optimization
5. **Security**: Review and enhance security configurations
6. **Performance**: Optimize database queries and Lambda functions

## Support and Resources

- **AWS RDS Documentation**: https://docs.aws.amazon.com/rds/
- **AWS DMS Documentation**: https://docs.aws.amazon.com/dms/
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest

For additional help, refer to the troubleshooting guide and performance optimization documentation.

# AWS ETL Architecture Designs - Master Prompt

## Overview
ETL (Extract, Transform, Load) is the process of extracting data from various sources, transforming it into a usable format, and loading it into a data warehouse or data lake. This document serves as the master guide for implementing various ETL architectural approaches on AWS.

## Architecture 1: Serverless ETL with Lambda
**Components:**
- Data Sources: RDS, S3, APIs, SaaS platforms
- Processing: AWS Lambda functions
- Orchestration: Amazon EventBridge or CloudWatch Events
- Queue: Amazon SQS for decoupling
- Storage: Amazon S3 (staging) → Amazon Redshift (warehouse)
- Monitoring: CloudWatch Logs and Metrics

**Flow:**
1. EventBridge triggers Lambda on schedule or events
2. Lambda extracts data from various sources
3. Data transformation logic in Lambda
4. Transformed data staged in S3
5. Lambda loads data into Redshift
6. Error handling via SQS dead letter queues

**Benefits:**
- No server management
- Automatic scaling
- Pay-per-execution pricing
- Quick deployment and iteration

**Use Cases:**
- Small to medium data volumes (<15 minutes processing)
- Event-driven data pipelines
- Simple transformations
- Cost-sensitive environments

## Architecture 2: AWS Glue ETL Pipeline
**Components:**
- Data Sources: S3, RDS, Redshift, DynamoDB
- ETL Engine: AWS Glue (Apache Spark)
- Data Catalog: AWS Glue Data Catalog
- Orchestration: AWS Glue Workflows or Step Functions
- Storage: S3 Data Lake → Redshift/Athena
- Monitoring: Glue job metrics and CloudWatch

**Flow:**
1. Glue Crawler discovers and catalogs data sources
2. Glue ETL job extracts data using Spark
3. Built-in or custom transformations applied
4. Data quality checks and validation
5. Cleaned data loaded to target warehouse
6. Automatic schema evolution handling

**Benefits:**
- Fully managed Spark environment
- Built-in data catalog and schema discovery
- Handles large datasets efficiently
- Visual ETL development interface
- Automatic scaling

**Use Cases:**
- Large data volumes (GB to TB)
- Complex transformations
- Data lake architectures
- Schema evolution requirements

## Architecture 3: Real-time Streaming ETL with Kinesis
**Components:**
- Data Sources: Application logs, IoT devices, databases (CDC)
- Ingestion: Amazon Kinesis Data Streams
- Processing: Kinesis Data Analytics or Lambda
- Storage: Kinesis Data Firehose → S3 → Redshift
- Real-time Views: Amazon OpenSearch (Elasticsearch)
- Monitoring: CloudWatch and Kinesis Analytics metrics

**Flow:**
1. Data producers send to Kinesis Data Streams
2. Kinesis Analytics processes streaming data
3. Real-time transformations and aggregations
4. Processed data sent to Firehose
5. Firehose buffers and loads to S3/Redshift
6. Near real-time dashboards from OpenSearch

**Benefits:**
- Real-time data processing
- High throughput and low latency
- Built-in scaling and partitioning
- Multiple consumption patterns

**Use Cases:**
- Real-time analytics
- IoT data processing
- Log analysis
- Fraud detection
- Live dashboards

## Architecture 4: Batch ETL with EMR
**Components:**
- Data Sources: S3, HDFS, databases
- Processing: Amazon EMR (Hadoop/Spark cluster)
- Storage: S3 Data Lake
- Orchestration: Apache Airflow on EMR or Step Functions
- Notebooks: EMR Notebooks or SageMaker
- Monitoring: EMR console and CloudWatch

**Flow:**
1. EMR cluster provisions on demand or persistent
2. Spark/Hadoop jobs extract data from sources
3. Large-scale parallel transformations
4. Data quality validation and cleansing
5. Partitioned data written to S3
6. Optional: Load summary data to Redshift

**Benefits:**
- Handles very large datasets (TB to PB)
- Full Hadoop ecosystem available
- Flexible cluster sizing
- Support for multiple processing frameworks

**Use Cases:**
- Big data processing
- Complex machine learning pipelines
- Historical data migration
- Advanced analytics workloads

## Architecture 5: Database-Centric ETL with RDS/Aurora
**Components:**
- Data Sources: Multiple databases, APIs, files
- Processing: Amazon RDS/Aurora with stored procedures
- Staging: Dedicated staging database
- Orchestration: AWS Data Pipeline or Step Functions
- Storage: RDS → S3 → Redshift
- Monitoring: RDS Performance Insights

**Flow:**
1. Data Pipeline orchestrates extraction
2. Source data pulled into staging RDS
3. SQL-based transformations in database
4. Data validation and quality checks
5. Transformed data exported to S3
6. Final load to data warehouse

**Benefits:**
- Familiar SQL-based transformations
- ACID transaction support
- Existing database skills utilization
- Strong consistency guarantees

**Use Cases:**
- SQL-heavy transformation logic
- Transactional data processing
- Legacy system integration
- Regulatory compliance requirements

## Architecture 6: Containerized ETL with ECS/EKS
**Components:**
- Data Sources: Various APIs, databases, files
- Container Platform: Amazon ECS or EKS
- Processing: Custom containers with ETL logic
- Orchestration: AWS Batch or Kubernetes Jobs
- Storage: S3, EFS for shared data
- Registry: Amazon ECR for container images

**Flow:**
1. Batch or Kubernetes job schedules containers
2. Containers pull data from multiple sources
3. Custom business logic for transformations
4. Parallel processing across multiple containers
5. Results aggregated and stored
6. Container cleanup and resource deallocation

**Benefits:**
- Language and framework flexibility
- Portable across environments
- Fine-grained resource control
- Easy to version and deploy

**Use Cases:**
- Complex custom logic
- Multi-language processing
- Microservices architecture
- Hybrid cloud deployments

## Architecture 7: Data Pipeline with Step Functions
**Components:**
- Data Sources: Multiple heterogeneous sources
- Orchestration: AWS Step Functions
- Processing: Combination of Lambda, Glue, EMR
- Storage: S3 for staging and final storage
- Error Handling: Built-in retry and error states
- Monitoring: Step Functions execution history

**Flow:**
1. Step Function state machine defines workflow
2. Parallel extraction from multiple sources
3. Different processing engines for different data types
4. Data validation and quality gates
5. Conditional logic for error handling
6. Final aggregation and loading

**Benefits:**
- Visual workflow definition
- Built-in error handling and retries
- Coordinated parallel processing
- Audit trail of executions

**Use Cases:**
- Complex multi-step workflows
- Mixed processing requirements
- Error-prone data sources
- Compliance and audit requirements

## Data Source Integration Patterns

### Database Sources:
- RDS/Aurora → AWS DMS → S3 → Processing
- PostgreSQL → Lambda → Transform → Redshift
- MySQL → Glue Connection → Direct processing

### File-based Sources:
- S3 Trigger → Lambda → Process → Target
- FTP → Lambda → S3 → Glue → Warehouse
- Local Files → DataSync → S3 → Pipeline

### API Sources:
- REST API → Lambda → S3 → Processing
- GraphQL → Custom Container → Transform → Load
- Webhook → API Gateway → Lambda → Pipeline

### Streaming Sources:
- Kafka → MSK → Kinesis Analytics → S3
- Database CDC → DMS → Kinesis → Processing
- IoT Core → Kinesis → Lambda → Warehouse

## Data Transformation Patterns

### Common Transformations:
- **Data Cleaning:** Remove duplicates, handle nulls, standardize formats
- **Data Enrichment:** Lookup tables, geocoding, calculated fields
- **Data Aggregation:** Rollups, summaries, statistical calculations
- **Data Normalization:** Convert to standard formats and schemas
- **Data Validation:** Quality checks, business rule validation

### Transformation Tools:
- **AWS Glue:** Visual ETL, built-in transformations, custom Spark code
- **Lambda:** Python/Node.js for simple transformations
- **EMR:** Complex Spark/Hadoop transformations
- **Kinesis Analytics:** SQL-based stream transformations

## Target Data Store Options

### Data Warehouses:
- **Amazon Redshift:** Columnar, fast queries, BI integration
- **Snowflake on AWS:** Elastic scaling, multi-cloud support
- **Amazon Athena:** Serverless SQL queries on S3

### Data Lakes:
- **S3 with Glue Catalog:** Cost-effective, flexible schema
- **Lake Formation:** Managed data lake with security
- **Delta Lake on EMR:** ACID transactions on data lake

### Operational Stores:
- **DynamoDB:** NoSQL for applications
- **OpenSearch:** Search and analytics
- **RDS:** Traditional relational database

## Performance Optimization

### Data Partitioning:
- Partition by date, region, or business unit
- Use appropriate file sizes (128MB - 1GB)
- Optimize for query patterns

### Parallel Processing:
- Leverage multiple Lambda functions
- Use Glue with multiple workers
- EMR cluster auto-scaling

### Data Compression:
- Use columnar formats (Parquet, ORC)
- Apply appropriate compression algorithms
- Balance compression ratio vs. processing speed

### Caching Strategies:
- Cache frequently accessed lookup data
- Use ElastiCache for transformation logic
- Implement intelligent data freshness policies

## Security and Compliance

### Access Control:
- IAM roles with least privilege
- VPC and security groups for network isolation
- Encryption at rest and in transit

### Data Governance:
- AWS Lake Formation for fine-grained access
- Data lineage tracking
- Audit logging with CloudTrail

### Compliance Features:
- Data masking and tokenization
- GDPR compliance with deletion capabilities
- SOX compliance with audit trails

## Monitoring and Alerting

### Key Metrics:
- Pipeline execution time and success rate
- Data quality metrics and anomaly detection
- Cost per pipeline run
- Resource utilization

### Monitoring Tools:
- CloudWatch for AWS service metrics
- Custom metrics for business KPIs
- X-Ray for distributed tracing
- Third-party tools integration

### Alerting Strategies:
- Pipeline failure notifications
- Data quality threshold breaches
- Cost anomaly detection
- SLA violation alerts

## Cost Optimization

### Compute Optimization:
- Use Spot instances for fault-tolerant workloads
- Right-size EMR clusters
- Lambda memory optimization for performance/cost balance

### Storage Optimization:
- S3 lifecycle policies for data archival
- Intelligent tiering for varying access patterns
- Data compression and format optimization

### Scheduling Optimization:
- Off-peak processing windows
- Batch processing to reduce overhead
- Resource sharing across pipelines

## Architecture Selection Guide

### Decision Criteria:
| Factor | Lambda | Glue | Kinesis | EMR | ECS/EKS | Step Functions |
|--------|--------|------|---------|-----|---------|----------------|
| Data Volume | <10GB | 10GB-10TB | Streaming | >10TB | Variable | Variable |
| Complexity | Simple | Medium | Stream logic | Complex | Very Complex | Orchestration |
| Real-time Need | Near RT | Batch | Real-time | Batch | Flexible | Batch |
| Cost (Small scale) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| Operational Overhead | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐ | ⭐⭐⭐ |
| Customization | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

### Quick Selection Guide:
- **Small, frequent jobs:** Lambda + EventBridge
- **Medium batch processing:** AWS Glue
- **Real-time processing:** Kinesis Analytics
- **Big data workloads:** EMR
- **Complex custom logic:** ECS/EKS
- **Multi-step workflows:** Step Functions + mixed services

## Implementation Guidelines

### For Each Architecture Implementation:
1. **Create comprehensive Terraform infrastructure code**
2. **Include architecture diagrams (Mermaid format)**
3. **Provide sample data and transformation logic**
4. **Include monitoring and alerting setup**
5. **Document security best practices**
6. **Provide cost estimation examples**
7. **Include troubleshooting guides**
8. **Add performance optimization recommendations**

### Standard Folder Structure:
```
architecture-X-name/
├── README.md
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
├── diagrams/
│   ├── architecture-overview.md
│   └── data-flow.md
├── src/
│   ├── lambda/ (if applicable)
│   ├── glue/ (if applicable)
│   └── containers/ (if applicable)
├── monitoring/
│   ├── cloudwatch-dashboards.json
│   └── alerts.yaml
└── docs/
    ├── deployment-guide.md
    ├── cost-analysis.md
    └── troubleshooting.md
```

This master prompt should guide all implementations to ensure consistency, completeness, and best practices across all AWS ETL architecture designs.

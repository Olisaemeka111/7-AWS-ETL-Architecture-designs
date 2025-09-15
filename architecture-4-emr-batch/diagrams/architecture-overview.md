# Architecture 4: EMR Batch ETL - Architecture Overview

## High-Level Architecture Diagram

```mermaid
graph TB
    subgraph "Data Sources"
        S3_RAW[(S3 Raw Data)]
        HDFS[HDFS Cluster]
        RDS[(RDS Database)]
        API[External APIs]
        LOGS[Log Files]
    end
    
    subgraph "EMR Cluster"
        MASTER[Master Node]
        CORE[Core Nodes]
        TASK[Task Nodes]
        SPARK[Apache Spark]
        HADOOP[Apache Hadoop]
        HIVE[Apache Hive]
        PIG[Apache Pig]
    end
    
    subgraph "Orchestration"
        AIRFLOW[Apache Airflow]
        STEP[EMR Steps]
        CRON[Cron Jobs]
    end
    
    subgraph "Processing Engines"
        SPARK_JOBS[Spark Jobs]
        HADOOP_JOBS[Hadoop Jobs]
        HIVE_QUERIES[Hive Queries]
        ML[ML Pipelines]
    end
    
    subgraph "Data Storage"
        S3_PROCESSED[(S3 Processed Data)]
        S3_AGGREGATED[(S3 Aggregated Data)]
        REDSHIFT[(Redshift Warehouse)]
        GLUE_CATALOG[Glue Data Catalog]
    end
    
    subgraph "Monitoring"
        EMR_MONITOR[EMR Console]
        CLOUDWATCH[CloudWatch]
        GANGILA[Ganglia]
        SPARK_UI[Spark UI]
    end
    
    %% Data Flow
    S3_RAW --> EMR_CLUSTER
    HDFS --> EMR_CLUSTER
    RDS --> EMR_CLUSTER
    API --> EMR_CLUSTER
    LOGS --> EMR_CLUSTER
    
    AIRFLOW --> STEP
    CRON --> STEP
    STEP --> EMR_CLUSTER
    
    EMR_CLUSTER --> SPARK_JOBS
    EMR_CLUSTER --> HADOOP_JOBS
    EMR_CLUSTER --> HIVE_QUERIES
    EMR_CLUSTER --> ML
    
    SPARK_JOBS --> S3_PROCESSED
    HADOOP_JOBS --> S3_PROCESSED
    HIVE_QUERIES --> S3_AGGREGATED
    ML --> S3_AGGREGATED
    
    S3_PROCESSED --> REDSHIFT
    S3_AGGREGATED --> REDSHIFT
    S3_PROCESSED --> GLUE_CATALOG
    
    EMR_CLUSTER --> EMR_MONITOR
    EMR_CLUSTER --> CLOUDWATCH
    EMR_CLUSTER --> GANGILA
    EMR_CLUSTER --> SPARK_UI
```

## Data Flow Diagram

```mermaid
sequenceDiagram
    participant AF as Airflow
    participant EMR as EMR Cluster
    participant S3 as S3 Data Lake
    participant SPARK as Spark Jobs
    participant HADOOP as Hadoop Jobs
    participant RS as Redshift
    participant GC as Glue Catalog
    
    AF->>EMR: Trigger EMR Step
    EMR->>S3: Read Raw Data
    S3-->>EMR: Return Data
    
    EMR->>SPARK: Execute Spark Job
    SPARK->>SPARK: Process Data
    SPARK->>S3: Write Processed Data
    
    EMR->>HADOOP: Execute Hadoop Job
    HADOOP->>HADOOP: Process Data
    HADOOP->>S3: Write Aggregated Data
    
    EMR->>GC: Update Data Catalog
    EMR->>RS: Load to Warehouse
    EMR->>AF: Job Complete
    
    Note over EMR,RS: Big Data Processing Pipeline
    Note over S3,GC: Data Lake & Catalog
```

## Component Details

### EMR Cluster Configuration
- **Master Node**: Cluster management and job coordination
- **Core Nodes**: Persistent storage and processing
- **Task Nodes**: Auto-scaling compute capacity
- **Applications**: Spark, Hadoop, Hive, Pig, HBase

### Processing Engines
- **Apache Spark**: Fast, general-purpose cluster computing
- **Apache Hadoop**: Distributed storage and processing
- **Apache Hive**: Data warehouse software for querying
- **Apache Pig**: High-level platform for data analysis

### Orchestration Options
- **Apache Airflow**: Workflow orchestration and scheduling
- **EMR Steps**: Native EMR job execution
- **Cron Jobs**: Simple scheduling for batch jobs
- **AWS Step Functions**: Serverless workflow orchestration

## EMR Cluster Types

### Transient Clusters
```mermaid
graph LR
    A[Job Submission] --> B[Cluster Creation]
    B --> C[Job Execution]
    C --> D[Cluster Termination]
    
    style A fill:#e1f5fe
    style D fill:#c8e6c9
```

### Persistent Clusters
```mermaid
graph LR
    A[Cluster Creation] --> B[Cluster Running]
    B --> C[Job Submission 1]
    B --> D[Job Submission 2]
    B --> E[Job Submission N]
    C --> B
    D --> B
    E --> B
    
    style A fill:#e1f5fe
    style B fill:#fff3e0
```

## Spark Job Architecture

### Spark Application Structure
```mermaid
graph TB
    subgraph "Spark Driver"
        DAG[DAG Scheduler]
        TASK[Task Scheduler]
        EXEC[Executor Backend]
    end
    
    subgraph "Spark Executors"
        EXEC1[Executor 1]
        EXEC2[Executor 2]
        EXEC3[Executor N]
    end
    
    subgraph "Cluster Manager"
        YARN[YARN Resource Manager]
        MESOS[Mesos Master]
        STANDALONE[Standalone Master]
    end
    
    DAG --> TASK
    TASK --> EXEC
    EXEC --> YARN
    YARN --> EXEC1
    YARN --> EXEC2
    YARN --> EXEC3
```

### Spark Processing Pipeline
```mermaid
flowchart TD
    A[Raw Data] --> B[Data Ingestion]
    B --> C[Data Validation]
    C --> D[Data Transformation]
    D --> E[Data Aggregation]
    E --> F[Data Quality Checks]
    F --> G[Data Loading]
    G --> H[Data Warehouse]
    
    style A fill:#e1f5fe
    style H fill:#c8e6c9
```

## Performance Optimization

### Auto-scaling Configuration
```python
# EMR auto-scaling configuration
auto_scaling_config = {
    "AutoScalingPolicy": {
        "Constraints": {
            "MinCapacity": 2,
            "MaxCapacity": 20
        },
        "Rules": [
            {
                "Name": "ScaleOutMemoryPercentage",
                "Description": "Scale out based on memory usage",
                "Action": {
                    "SimpleScalingPolicyConfiguration": {
                        "AdjustmentType": "CHANGE_IN_CAPACITY",
                        "ScalingAdjustment": 2,
                        "CoolDown": 300
                    }
                },
                "Trigger": {
                    "CloudWatchAlarmDefinition": {
                        "ComparisonOperator": "GREATER_THAN",
                        "EvaluationPeriods": 2,
                        "MetricName": "MemoryPercentage",
                        "Namespace": "AWS/ElasticMapReduce",
                        "Period": 300,
                        "Statistic": "AVERAGE",
                        "Threshold": 75.0
                    }
                }
            }
        ]
    }
}
```

### Spot Instance Configuration
```python
# Spot instance configuration for cost optimization
spot_config = {
    "Instances": {
        "InstanceGroups": [
            {
                "Name": "Task",
                "Market": "SPOT",
                "InstanceRole": "TASK",
                "InstanceType": "m5.xlarge",
                "InstanceCount": 10,
                "BidPrice": "0.10"
            }
        ]
    }
}
```

## Data Processing Patterns

### Batch Processing Pattern
```mermaid
sequenceDiagram
    participant SCHED as Scheduler
    participant EMR as EMR Cluster
    participant S3 as S3 Storage
    participant SPARK as Spark Engine
    participant DW as Data Warehouse
    
    SCHED->>EMR: Trigger Batch Job
    EMR->>S3: Read Source Data
    S3-->>EMR: Return Data
    EMR->>SPARK: Process Data
    SPARK->>SPARK: Apply Transformations
    SPARK->>S3: Write Results
    EMR->>DW: Load to Warehouse
    EMR->>SCHED: Job Complete
```

### Incremental Processing Pattern
```mermaid
flowchart TD
    A[Checkpoint Store] --> B[Read Last Processed]
    B --> C[Query New Data]
    C --> D[Process Increment]
    D --> E[Update Checkpoint]
    E --> F[Load to Warehouse]
    
    style A fill:#e1f5fe
    style F fill:#c8e6c9
```

## Security Configuration

### IAM Roles and Policies
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
                "arn:aws:s3:::data-lake-bucket/*",
                "arn:aws:s3:::data-lake-bucket"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "glue:GetTable",
                "glue:GetDatabase",
                "glue:GetPartitions"
            ],
            "Resource": "*"
        }
    ]
}
```

### VPC Configuration
- Deploy EMR cluster in private subnets
- Use VPC endpoints for S3 access
- Configure security groups for network isolation
- Enable VPC flow logs for monitoring

## Monitoring and Alerting

### Key Metrics
- **Cluster Health**: Node status, job success rate
- **Resource Utilization**: CPU, memory, disk usage
- **Job Performance**: Execution time, throughput
- **Cost Metrics**: Instance hours, data transfer costs

### CloudWatch Alarms
```yaml
alarms:
  - name: "EMR-Cluster-Node-Failure"
    metric: "IsIdle"
    threshold: 0
    comparison: "LessThanThreshold"
  
  - name: "EMR-Job-Failure-Rate"
    metric: "JobsFailed"
    threshold: 5
    comparison: "GreaterThanThreshold"
  
  - name: "EMR-HDFS-Utilization"
    metric: "HDFSUtilization"
    threshold: 80
    comparison: "GreaterThanThreshold"
```

## Cost Optimization

### Instance Type Selection
```python
# Instance type recommendations based on workload
instance_recommendations = {
    "memory_intensive": {
        "master": "m5.2xlarge",
        "core": "r5.xlarge",
        "task": "r5.large"
    },
    "compute_intensive": {
        "master": "c5.2xlarge",
        "core": "c5.xlarge",
        "task": "c5.large"
    },
    "storage_intensive": {
        "master": "i3.2xlarge",
        "core": "i3.xlarge",
        "task": "i3.large"
    }
}
```

### Spot Instance Strategy
```python
# Spot instance allocation strategy
spot_allocation = {
    "core_nodes": "0%",  # Use On-Demand for core nodes
    "task_nodes": "100%",  # Use Spot for task nodes
    "fallback": "On-Demand"  # Fallback to On-Demand if Spot unavailable
}
```

This comprehensive architecture overview provides the foundation for implementing a robust EMR-based batch ETL pipeline with proper scaling, monitoring, and cost optimization strategies.

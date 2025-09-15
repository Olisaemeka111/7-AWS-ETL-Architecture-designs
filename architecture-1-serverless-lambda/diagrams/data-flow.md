# Architecture 1: Serverless ETL with Lambda - Data Flow Diagram

## Detailed Data Flow Sequence

```mermaid
sequenceDiagram
    participant EB as EventBridge
    participant L1 as Extract Lambda
    participant RDS as RDS Database
    participant API as External API
    participant SQS as SQS Queue
    participant L2 as Transform Lambda
    participant S3 as S3 Staging
    participant L3 as Load Lambda
    participant RS as Redshift
    participant DLQ as Dead Letter Queue
    participant CW as CloudWatch
    
    Note over EB: Scheduled Trigger (Daily 2 AM)
    EB->>L1: Trigger Extract Job
    
    Note over L1: Data Extraction Phase
    L1->>RDS: Query Source Data
    RDS-->>L1: Return Dataset
    L1->>API: Fetch External Data
    API-->>L1: Return API Response
    L1->>L1: Validate & Format Data
    L1->>SQS: Send Raw Data Messages
    L1->>CW: Log Extraction Metrics
    
    Note over SQS: Message Queue Processing
    SQS->>L2: Trigger Transform Job
    
    Note over L2: Data Transformation Phase
    L2->>L2: Parse SQS Messages
    L2->>L2: Apply Business Logic
    L2->>L2: Data Quality Checks
    L2->>L2: Schema Validation
    L2->>S3: Store Transformed Data
    L2->>CW: Log Transform Metrics
    
    Note over S3: Staging Storage
    S3->>L3: Trigger Load Job
    
    Note over L3: Data Loading Phase
    L3->>S3: Read Transformed Data
    L3->>L3: Prepare for Warehouse
    L3->>RS: Bulk Load to Redshift
    RS-->>L3: Confirm Load Success
    L3->>CW: Log Load Metrics
    
    Note over DLQ: Error Handling
    alt Processing Error
        L1->>DLQ: Failed Messages
        L2->>DLQ: Failed Messages
        L3->>DLQ: Failed Messages
    end
    
    Note over CW: Monitoring & Alerting
    CW->>CW: Collect Metrics
    CW->>CW: Trigger Alarms
```

## Data Processing Flow

```mermaid
flowchart TD
    A[Data Sources] --> B[Extract Lambda]
    B --> C{Data Validation}
    C -->|Valid| D[SQS Queue]
    C -->|Invalid| E[Error Logging]
    D --> F[Transform Lambda]
    F --> G{Transformation Success}
    G -->|Success| H[S3 Staging]
    G -->|Failure| I[Dead Letter Queue]
    H --> J[Load Lambda]
    J --> K{Load Success}
    K -->|Success| L[Redshift Warehouse]
    K -->|Failure| M[Error Handling]
    
    E --> N[CloudWatch Logs]
    I --> N
    M --> N
    
    L --> O[Analytics & Reporting]
    
    style A fill:#e1f5fe
    style L fill:#c8e6c9
    style N fill:#ffcdd2
    style O fill:#fff3e0
```

## Error Handling Flow

```mermaid
flowchart TD
    A[Lambda Function] --> B{Execution Success}
    B -->|Success| C[Continue Processing]
    B -->|Failure| D[Error Classification]
    
    D --> E{Error Type}
    E -->|Retryable| F[Exponential Backoff]
    E -->|Non-Retryable| G[Dead Letter Queue]
    
    F --> H{Retry Count}
    H -->|< Max Retries| I[Retry Execution]
    H -->|>= Max Retries| G
    
    I --> A
    G --> J[Error Notification]
    J --> K[Manual Intervention]
    
    style A fill:#e3f2fd
    style C fill:#c8e6c9
    style G fill:#ffcdd2
    style K fill:#fff3e0
```

## Data Volume and Performance Flow

```mermaid
graph LR
    subgraph "Small Volume (< 1GB)"
        A1[Single Lambda] --> B1[Direct Processing]
        B1 --> C1[Immediate Load]
    end
    
    subgraph "Medium Volume (1-10GB)"
        A2[Multiple Lambdas] --> B2[Parallel Processing]
        B2 --> C2[Batch Load]
    end
    
    subgraph "Large Volume (> 10GB)"
        A3[Lambda + S3] --> B3[Chunked Processing]
        B3 --> C3[Streaming Load]
    end
    
    style A1 fill:#e8f5e8
    style A2 fill:#fff3e0
    style A3 fill:#ffebee
```

## Security and Access Flow

```mermaid
sequenceDiagram
    participant U as User/System
    participant IAM as IAM Role
    participant L as Lambda
    participant S3 as S3 Bucket
    participant RDS as RDS
    participant RS as Redshift
    
    U->>IAM: Assume Role
    IAM->>L: Grant Permissions
    L->>S3: Access with IAM Role
    L->>RDS: Connect with IAM Role
    L->>RS: Load with IAM Role
    
    Note over IAM: Least Privilege Access
    Note over L: VPC Security Groups
    Note over S3: Bucket Policies
    Note over RDS: Security Groups
    Note over RS: Cluster Security
```

## Cost Optimization Flow

```mermaid
flowchart TD
    A[ETL Pipeline] --> B[Cost Monitoring]
    B --> C{Cost Threshold}
    C -->|Below| D[Continue Normal Operation]
    C -->|Above| E[Cost Optimization]
    
    E --> F[Lambda Memory Optimization]
    E --> G[S3 Storage Class Optimization]
    E --> H[Redshift Scaling]
    E --> I[Schedule Optimization]
    
    F --> J[Performance vs Cost Balance]
    G --> J
    H --> J
    I --> J
    
    J --> K[Updated Configuration]
    K --> A
    
    style A fill:#e3f2fd
    style E fill:#fff3e0
    style J fill:#c8e6c9
```

## Data Quality Flow

```mermaid
flowchart TD
    A[Raw Data] --> B[Data Validation]
    B --> C{Quality Check}
    C -->|Pass| D[Transform Data]
    C -->|Fail| E[Data Quality Report]
    
    D --> F[Business Rule Validation]
    F --> G{Rule Compliance}
    G -->|Pass| H[Load to Warehouse]
    G -->|Fail| I[Data Correction]
    
    I --> J{Correction Success}
    J -->|Success| D
    J -->|Failure| K[Manual Review]
    
    E --> L[Quality Dashboard]
    K --> L
    H --> M[Data Lineage Tracking]
    
    style A fill:#e1f5fe
    style H fill:#c8e6c9
    style E fill:#ffcdd2
    style L fill:#fff3e0
```

## Monitoring and Alerting Flow

```mermaid
sequenceDiagram
    participant L as Lambda Functions
    participant CW as CloudWatch
    participant SNS as SNS Topic
    participant EMAIL as Email Alert
    participant SLACK as Slack Alert
    participant DASH as Dashboard
    
    L->>CW: Send Metrics
    CW->>CW: Evaluate Thresholds
    CW->>SNS: Send Alert
    SNS->>EMAIL: Notify Team
    SNS->>SLACK: Notify Channel
    CW->>DASH: Update Dashboard
    
    Note over CW: Real-time Monitoring
    Note over SNS: Multi-channel Alerts
    Note over DASH: Visual Analytics
```

## Data Lineage Flow

```mermaid
graph TD
    A[Source Systems] --> B[Extract Lambda]
    B --> C[SQS Queue]
    C --> D[Transform Lambda]
    D --> E[S3 Staging]
    E --> F[Load Lambda]
    F --> G[Redshift Warehouse]
    
    H[Data Catalog] --> I[Schema Registry]
    I --> J[Lineage Tracking]
    J --> K[Impact Analysis]
    
    B --> H
    D --> H
    F --> H
    
    style A fill:#e1f5fe
    style G fill:#c8e6c9
    style H fill:#fff3e0
    style K fill:#f3e5f5
```

This data flow documentation provides comprehensive coverage of all aspects of the serverless ETL pipeline, including processing flows, error handling, security, cost optimization, data quality, monitoring, and data lineage tracking.

# Architecture 1: Serverless ETL with Lambda - Architecture Overview

## High-Level Architecture Diagram

```mermaid
graph TB
    subgraph "Data Sources"
        RDS[(RDS Database)]
        S3_SRC[(S3 Source Data)]
        API[External APIs]
        SAAS[SaaS Platforms]
    end
    
    subgraph "Orchestration"
        EB[EventBridge]
        CW[CloudWatch Events]
    end
    
    subgraph "Processing Layer"
        L1[Lambda: Extract]
        L2[Lambda: Transform]
        L3[Lambda: Load]
    end
    
    subgraph "Queue & Error Handling"
        SQS[SQS Queue]
        DLQ[SQS Dead Letter Queue]
    end
    
    subgraph "Storage"
        S3_STAGING[(S3 Staging)]
        REDSHIFT[(Redshift Warehouse)]
    end
    
    subgraph "Monitoring"
        CWL[CloudWatch Logs]
        CWM[CloudWatch Metrics]
    end
    
    %% Data Flow
    RDS --> L1
    S3_SRC --> L1
    API --> L1
    SAAS --> L1
    
    EB --> L1
    CW --> L1
    
    L1 --> SQS
    SQS --> L2
    L2 --> S3_STAGING
    S3_STAGING --> L3
    L3 --> REDSHIFT
    
    SQS -.-> DLQ
    
    L1 --> CWL
    L2 --> CWL
    L3 --> CWL
    
    L1 --> CWM
    L2 --> CWM
    L3 --> CWM
```

## Data Flow Diagram

```mermaid
sequenceDiagram
    participant EB as EventBridge
    participant L1 as Extract Lambda
    participant SQS as SQS Queue
    participant L2 as Transform Lambda
    participant S3 as S3 Staging
    participant L3 as Load Lambda
    participant RDS as Redshift
    
    EB->>L1: Trigger (Schedule/Event)
    L1->>L1: Extract from sources
    L1->>SQS: Send raw data
    SQS->>L2: Trigger transform
    L2->>L2: Apply transformations
    L2->>S3: Store transformed data
    S3->>L3: Trigger load
    L3->>RDS: Load to warehouse
    
    Note over L1,L3: Error handling via DLQ
    Note over SQS: Decoupling layer
```

## Component Details

### EventBridge Rules
- **Schedule-based**: Daily/hourly data extraction
- **Event-based**: File upload triggers
- **Cross-account**: Multi-tenant data sources

### Lambda Functions
- **Extract Lambda**: 
  - Connects to multiple data sources
  - Handles authentication
  - Implements retry logic
  - Sends to SQS for decoupling

- **Transform Lambda**:
  - Data cleaning and validation
  - Business logic transformations
  - Schema mapping
  - Quality checks

- **Load Lambda**:
  - Bulk data loading to Redshift
  - Incremental updates
  - Data type conversions
  - Error handling and rollback

### SQS Configuration
- **Standard Queue**: For normal processing
- **Dead Letter Queue**: For failed messages
- **Visibility Timeout**: Based on Lambda timeout
- **Message Retention**: 14 days default

### Storage Strategy
- **S3 Staging**: 
  - Partitioned by date/source
  - Compressed format (Parquet)
  - Lifecycle policies for cost optimization
  
- **Redshift**:
  - Columnar storage
  - Distribution keys for performance
  - Sort keys for query optimization

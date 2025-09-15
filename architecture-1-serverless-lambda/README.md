# Architecture 1: Serverless ETL with Lambda

## Overview
This architecture implements a fully serverless ETL pipeline using AWS Lambda functions for data processing, orchestrated by EventBridge, with SQS for decoupling and error handling.

## 🏗️ Architecture Components
- **Data Sources**: RDS, S3, APIs, SaaS platforms
- **Processing**: AWS Lambda functions (Extract, Transform, Load)
- **Orchestration**: Amazon EventBridge
- **Queue**: Amazon SQS for decoupling
- **Storage**: Amazon S3 (staging) → Amazon Redshift (warehouse)
- **Monitoring**: CloudWatch Logs and Metrics

## 🔄 Data Flow
1. EventBridge triggers Lambda on schedule or events
2. Lambda extracts data from various sources
3. Data transformation logic in Lambda
4. Transformed data staged in S3
5. Lambda loads data into Redshift
6. Error handling via SQS dead letter queues

## ✅ Benefits
- No server management
- Automatic scaling
- Pay-per-execution pricing
- Quick deployment and iteration

## 🎯 Use Cases
- Small to medium data volumes (<15 minutes processing)
- Event-driven data pipelines
- Simple transformations
- Cost-sensitive environments

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

### Deploy Lambda Functions
```bash
# Package and deploy extract function
cd src/lambda/extract
pip install -r requirements.txt -t .
zip -r extract.zip .
aws lambda update-function-code --function-name etl-extract --zip-file fileb://extract.zip
```

## 💰 Cost Estimation
- **Lambda**: ~$0.20 per 1M requests + compute time
- **S3**: ~$0.023 per GB stored
- **Redshift**: ~$0.25 per hour for dc2.large
- **SQS**: ~$0.40 per 1M requests
- **Total**: ~$125-200/month (depending on usage)

## 📊 Monitoring
- CloudWatch dashboards for pipeline metrics
- SQS dead letter queue monitoring
- Lambda error rates and duration
- Redshift query performance

## 📁 Project Structure
```
architecture-1-serverless-lambda/
├── README.md
├── diagrams/
│   ├── architecture-overview.md
│   └── data-flow.md
├── docs/
│   ├── deployment-guide.md
│   ├── cost-analysis.md
│   ├── troubleshooting.md
│   └── performance-optimization.md
├── monitoring/
│   ├── cloudwatch-dashboard.json
│   └── alerts.yaml
├── src/
│   └── lambda/
│       ├── extract/
│       ├── transform/
│       └── load/
└── terraform/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── modules/
```

## 🔧 Configuration
See [deployment-guide.md](docs/deployment-guide.md) for detailed configuration instructions.

## 🐛 Troubleshooting
See [troubleshooting.md](docs/troubleshooting.md) for common issues and solutions.

## 📈 Performance Optimization
See [performance-optimization.md](docs/performance-optimization.md) for optimization strategies.

## 🔒 Security
- IAM roles with least privilege
- VPC and security groups for network isolation
- Encryption at rest and in transit
- CloudTrail for audit logging
# AWS MSK Kafka Module

This module deploys AWS Managed Streaming for Apache Kafka (MSK) clusters with secure defaults and automatic scaling capabilities.

## Features

- **Secure by Default**: TLS encryption in transit and at rest
- **Monitoring**: Integrated CloudWatch logs and Prometheus metrics
- **Auto-scaling**: Configurable broker nodes and storage
- **Import Support**: Can import existing MSK clusters
- **Multi-AZ**: Deploys across multiple availability zones
- **Custom Configuration**: MSK-optimized Kafka settings

## Supported Kafka Versions

This module supports the following Kafka versions currently available in AWS MSK:

### ✅ Recommended Versions (Zookeeper-based):
- `3.5.1` (default)
- `3.4.0`
- `3.6.0`
- `3.7.x`
- `3.8.x`
- `3.9.x`

### ✅ KRaft Mode (Zookeeper-free):
- `3.7.x.kraft`
- `3.8.x.kraft`
- `3.9.x.kraft`
- `4.0.x.kraft`

### ⚠️ Legacy Support:
- `2.8.1` - **Deprecated**: May not be available in all AWS regions

## Version Compatibility Notes

- **Regional Availability**: Older versions like 2.8.1 may not be supported in all AWS regions
- **Default Version**: Uses Kafka 3.5.1 for optimal compatibility
- **KRaft Mode**: Supports up to 60 brokers (vs 30 for Zookeeper mode)
- **Recommendation**: Use version 3.5.1 or newer for best support

## Usage Example

```yaml
kind: kafka
flavor: aws-msk
version: '1.0'
spec:
  version_config:
    kafka_version: "3.5.1"
    instance_type: "kafka.m5.large"
  sizing:
    number_of_broker_nodes: 3
    volume_size: 100
    client_subnets_count: 3
```

## Configuration Options

### Version & Instance Configuration
- `kafka_version`: Kafka engine version (see supported versions above)
- `instance_type`: MSK broker instance type (kafka.t3.small to kafka.m7g.4xlarge)

### Sizing & Performance
- `number_of_broker_nodes`: Number of broker nodes per AZ (1-15)
- `volume_size`: EBS volume size per broker in GB (1-16384)
- `client_subnets_count`: Number of subnets for multi-AZ deployment (2-3)

### Import Configuration
- `cluster_arn`: ARN of existing MSK cluster to import (optional)

## Required Inputs

- `aws_cloud_account`: AWS cloud account configuration
- `vpc_details`: VPC configuration for MSK deployment

## Outputs

- `@facets/kafka`: Main Kafka cluster connection details
- `@facets/kafka-interface`: Interface for cross-flavor compatibility

## Security Features

- **Encryption at Rest**: Uses AWS KMS encryption
- **Encryption in Transit**: TLS for client-broker and inter-cluster communication
- **Network Security**: VPC-based with security groups
- **Monitoring**: CloudWatch logs and Prometheus metrics enabled

## Troubleshooting

### Version Not Supported Error
```
Error: Unsupported KafkaVersion [2.8.1]. Valid values: [3.4.0, 3.5.1, ...]
```
**Solution**: Update to a supported version like 3.5.1 or newer.

### Regional Availability
Some older Kafka versions may not be available in all AWS regions. If you encounter version compatibility issues:
1. Use a newer version (3.5.1+ recommended)
2. Check AWS MSK documentation for regional availability
3. Consider deploying in a different region if legacy version is required

## Monitoring

The module automatically configures:
- CloudWatch log groups for broker logs
- Prometheus JMX and Node exporters
- 7-day log retention
- Enhanced monitoring enabled

## Best Practices

1. **Use Latest Stable Version**: Prefer version 3.5.1 or newer
2. **Multi-AZ Deployment**: Use 3 broker nodes across 3 subnets
3. **Instance Sizing**: Start with kafka.m5.large and scale as needed
4. **Volume Size**: Start with 100GB and adjust based on retention needs
5. **Security**: Always use TLS encryption (enabled by default)

## AWS MSK Limits

- **Zookeeper Clusters**: Max 30 brokers per cluster
- **KRaft Clusters**: Max 60 brokers per cluster  
- **Volume Size**: 1GB to 16TB per broker
- **Retention**: Configure based on storage and cost requirements
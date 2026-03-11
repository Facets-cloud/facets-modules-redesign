# AWS SQS Queue Module

This module provisions an AWS Simple Queue Service (SQS) queue with comprehensive configuration options including FIFO support, dead letter queues, and encryption.

## Features

- **Queue Types**: Support for both Standard and FIFO queues
- **Dead Letter Queue**: Optional DLQ for failed message handling
- **Encryption**: Server-side encryption with AWS managed or custom KMS keys
- **IAM Policies**: Pre-configured policies for send, receive, and full access
- **Import Support**: Import existing SQS queues
- **Configurable Parameters**: Message retention, visibility timeout, long polling, and more

## Usage

### Basic Standard Queue

```yaml
version: '1.0'
flavor: standard
kind: sqs_queue
spec:
  queue_config:
    visibility_timeout_seconds: 30
    message_retention_seconds: 345600
  encryption_config:
    enable_encryption: true
```

### FIFO Queue with Content-Based Deduplication

```yaml
version: '1.0'
flavor: standard
kind: sqs_queue
spec:
  queue_config:
    fifo_queue: true
    content_based_deduplication: true
    visibility_timeout_seconds: 60
  encryption_config:
    enable_encryption: true
```

### Queue with Dead Letter Queue

```yaml
version: '1.0'
flavor: standard
kind: sqs_queue
spec:
  queue_config:
    visibility_timeout_seconds: 30
    message_retention_seconds: 345600
  dlq_config:
    enable_dlq: true
    max_receive_count: 3
  encryption_config:
    enable_encryption: true
```

### Queue with Custom KMS Key

```yaml
version: '1.0'
flavor: standard
kind: sqs_queue
spec:
  queue_config:
    visibility_timeout_seconds: 30
  encryption_config:
    enable_encryption: true
    kms_key_id: arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012
    kms_data_key_reuse_period_seconds: 300
```

### Import Existing Queue

```yaml
version: '1.0'
flavor: standard
kind: sqs_queue
spec:
  import_existing: true
  imports:
    queue_name: my-existing-queue
    queue_arn: arn:aws:sqs:us-east-1:123456789012:my-existing-queue
```

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| cloud_account | `@facets/aws_cloud_account` | Yes | AWS Cloud Account with provider configuration |

## Outputs

The module outputs the `@facets/sqs_queue` type with the following attributes:

### Attributes

| Name | Description |
|------|-------------|
| queue_name | SQS queue name |
| queue_url | SQS queue URL |
| queue_arn | SQS queue ARN |
| dlq_queue_name | Dead letter queue name (if enabled) |
| dlq_queue_url | Dead letter queue URL (if enabled) |
| dlq_queue_arn | Dead letter queue ARN (if enabled) |
| send_policy_arn | IAM policy ARN for sending messages |
| receive_policy_arn | IAM policy ARN for receiving messages |
| full_access_policy_arn | IAM policy ARN for full access |
| send_policy_name | IAM policy name for sending messages |
| receive_policy_name | IAM policy name for receiving messages |
| full_access_policy_name | IAM policy name for full access |

### Interfaces

```yaml
queue:
  name: Queue name
  url: Queue URL
  arn: Queue ARN
dlq:  # Only if DLQ is enabled
  name: DLQ name
  url: DLQ URL
  arn: DLQ ARN
```

## Configuration

### Queue Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| fifo_queue | boolean | false | Enable FIFO (First-In-First-Out) queue |
| content_based_deduplication | boolean | false | Enable content-based deduplication (FIFO only) |
| visibility_timeout_seconds | integer | 30 | Time a message is hidden after being received (0-43200) |
| message_retention_seconds | integer | 345600 | How long messages are retained (60-1209600) |
| max_message_size | integer | 262144 | Maximum message size in bytes (1024-262144) |
| delay_seconds | integer | 0 | Delivery delay for messages (0-900) |
| receive_wait_time_seconds | integer | 0 | Long polling wait time (0-20) |

### Dead Letter Queue Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| enable_dlq | boolean | false | Create a dead letter queue |
| max_receive_count | integer | 3 | Max receives before moving to DLQ (1-1000) |

### Encryption Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| enable_encryption | boolean | true | Enable server-side encryption |
| kms_key_id | string | null | Custom KMS key ARN (uses AWS managed key if not provided) |
| kms_data_key_reuse_period_seconds | integer | 300 | Data key reuse period (60-86400) |

## IAM Policies

The module creates three IAM policies for different access levels:

### Send Policy
Allows sending messages to the queue:
- `sqs:SendMessage`
- `sqs:GetQueueUrl`
- `sqs:GetQueueAttributes`

### Receive Policy
Allows receiving and processing messages:
- `sqs:ReceiveMessage`
- `sqs:DeleteMessage`
- `sqs:GetQueueUrl`
- `sqs:GetQueueAttributes`
- `sqs:ChangeMessageVisibility`

### Full Access Policy
Allows all SQS operations on the queue

## Naming Convention

Queues are automatically named using the pattern:
- Standard queues: `{instance_name}-{environment.unique_name}`
- FIFO queues: `{instance_name}-{environment.unique_name}.fifo`
- Dead letter queues: `{instance_name}-{environment.unique_name}-dlq[.fifo]`

## IAM Policy Usage with IRSA

The module creates IAM policies that can be attached to Kubernetes service accounts via IRSA (IAM Roles for Service Accounts). Here's how to use them:

### Producer Service (Send Messages)

```yaml
kind: service
flavor: aws
spec:
  cloud_permissions:
    aws:
      enable_irsa: true
      iam_policies:
        sqs_send:
          arn: "${sqs_queue.my-queue.out.attributes.send_policy_arn}"
  env:
    QUEUE_URL: "${sqs_queue.my-queue.out.attributes.queue_url}"
```

### Consumer Service (Receive Messages)

```yaml
kind: service
flavor: aws
spec:
  cloud_permissions:
    aws:
      enable_irsa: true
      iam_policies:
        sqs_receive:
          arn: "${sqs_queue.my-queue.out.attributes.receive_policy_arn}"
  env:
    QUEUE_URL: "${sqs_queue.my-queue.out.attributes.queue_url}"
    DLQ_URL: "${sqs_queue.my-queue.out.attributes.dlq_queue_url}"
```

### Worker Service (Send + Receive)

```yaml
kind: service
flavor: aws
spec:
  cloud_permissions:
    aws:
      enable_irsa: true
      iam_policies:
        sqs_full:
          arn: "${sqs_queue.my-queue.out.attributes.full_access_policy_arn}"
  env:
    QUEUE_URL: "${sqs_queue.my-queue.out.attributes.queue_url}"
```

**Note**: When using customer-managed KMS keys, the IAM policies automatically include `kms:Decrypt` and `kms:GenerateDataKey` permissions.

## Dead Letter Queue Workflow

When you enable DLQ, here's what happens:

1. **Consumer receives message** from main queue
2. **Processing fails**, message visibility timeout expires
3. **Message returns to queue**, receive count increments
4. **After max_receive_count attempts** (default: 3), message moves to DLQ
5. **DLQ retains message** for 14 days for investigation
6. **You investigate and fix** the processing issue
7. **Re-drive messages** from DLQ back to main queue

### Monitoring DLQ

Set up CloudWatch alarms to monitor DLQ depth:

```yaml
# CloudWatch alarm configuration (pseudo-code)
metric: ApproximateNumberOfMessagesVisible
queue_name: "${sqs_queue.my-queue.out.attributes.dlq_queue_name}"
threshold: > 0
action: Send alert to operations team
```

### Inspecting DLQ Messages

```bash
# List messages in DLQ
aws sqs receive-message \
  --queue-url "${DLQ_URL}" \
  --max-number-of-messages 10

# After fixing the issue, redrive messages
aws sqs start-message-move-task \
  --source-arn "${DLQ_ARN}" \
  --destination-arn "${QUEUE_ARN}"
```

## Output Reference Table

| Output Path | Type | Purpose | Example Value |
|-------------|------|---------|---------------|
| `attributes.queue_url` | string | Send/receive messages | `https://sqs.us-east-1.amazonaws.com/123/queue` |
| `attributes.queue_arn` | string | IAM policies, alarms | `arn:aws:sqs:us-east-1:123:queue` |
| `attributes.queue_name` | string | CloudWatch metrics | `myqueue-prod` |
| `attributes.region` | string | SDK configuration | `us-east-1` |
| `attributes.account_id` | string | Cross-account scenarios | `123456789012` |
| `attributes.is_fifo` | boolean | Queue type detection | `false` |
| `attributes.send_policy_arn` | string | Producer IRSA | `arn:aws:iam::123:policy/...` |
| `attributes.receive_policy_arn` | string | Consumer IRSA | `arn:aws:iam::123:policy/...` |
| `attributes.full_access_policy_arn` | string | Worker IRSA | `arn:aws:iam::123:policy/...` |
| `interfaces.queue.url` | string | Cloud-agnostic URL | Same as `queue_url` |
| `interfaces.dlq.url` | string | DLQ URL | `https://sqs.../queue-dlq` |

## Time Value Reference

Configuration uses seconds. Here's a quick reference:

| Human-Readable | Seconds | Parameter |
|----------------|---------|-----------|
| 30 seconds | 30 | Default visibility timeout |
| 5 minutes | 300 | Short visibility timeout |
| 15 minutes | 900 | Medium visibility timeout |
| 1 hour | 3600 | Long visibility timeout |
| 4 days | 345600 | Default message retention |
| 7 days | 604800 | 1 week retention |
| 14 days | 1209600 | Max retention, DLQ default |

## Monitoring Best Practices

### Key Metrics to Track

- **ApproximateNumberOfMessagesVisible** - Messages waiting in queue
- **ApproximateAgeOfOldestMessage** - Detect processing delays
- **NumberOfMessagesSent** - Producer throughput
- **NumberOfMessagesReceived** - Consumer throughput
- **NumberOfMessagesDeleted** - Successfully processed messages

### Recommended CloudWatch Alarms

```yaml
# High queue depth alarm
ApproximateNumberOfMessagesVisible > 1000 for 5 minutes

# Messages stuck in queue
ApproximateAgeOfOldestMessage > 3600 seconds

# DLQ has messages (needs investigation)
ApproximateNumberOfMessagesVisible (DLQ) > 0
```

## Troubleshooting

### Messages Not Appearing in Queue

**Symptom**: Producer sends messages but consumer doesn't receive them

**Solutions**:
1. Check producer has correct `send_policy_arn` attached
2. Verify `queue_url` is correct in producer configuration
3. Check IAM permissions include `sqs:SendMessage`
4. For FIFO queues, ensure deduplication ID is unique

### Consumer Not Receiving Messages

**Symptom**: Messages are in queue but consumer doesn't get them

**Solutions**:
1. Check consumer has correct `receive_policy_arn` attached
2. Verify `queue_url` is correct in consumer configuration
3. Check IAM permissions include `sqs:ReceiveMessage`
4. Increase `receive_wait_time_seconds` for long polling (reduces cost)
5. Check if another consumer is processing messages

### DLQ Filling Up

**Symptom**: Dead letter queue has many messages

**Solutions**:
1. Check DLQ message details to identify error pattern
2. Fix the processing logic causing failures
3. Increase `visibility_timeout_seconds` if processing takes longer
4. Increase `max_receive_count` if transient failures are common
5. After fixing, use `start-message-move-task` to redrive messages

### Permission Denied Errors

**Symptom**: `AccessDenied` or `403` errors when accessing queue

**Solutions**:
1. Verify IRSA is enabled in service module
2. Check policy ARN is correctly wired to service
3. For KMS encryption, ensure KMS permissions are included
4. Verify IAM role trust relationship includes EKS OIDC provider

### FIFO Queue Issues

**Symptom**: Messages are out of order or duplicated

**Solutions**:
1. Ensure `fifo_queue: true` is set
2. Provide unique `MessageGroupId` for each message
3. Enable `content_based_deduplication` to avoid providing deduplication IDs
4. Remember FIFO has lower throughput (300 TPS, 3000 with batching)

## Notes

- FIFO queues automatically append `.fifo` suffix to queue names
- Dead letter queues inherit the FIFO setting from the main queue
- Encryption is enabled by default using AWS managed keys
- DLQ messages are retained for 14 days by default
- All resources are tagged with environment tags and custom tags
- When using KMS encryption, IAM policies automatically include KMS permissions

# AWS SNS Topic Module

This module provisions an AWS Simple Notification Service (SNS) topic with comprehensive configuration options including FIFO support, dead letter queues for failed deliveries, and encryption.

## Features

- **Topic Types**: Support for both Standard and FIFO topics
- **Dead Letter Queue**: Optional SQS DLQ for failed message deliveries
- **Encryption**: Server-side encryption with AWS managed or custom KMS keys
- **IAM Policies**: Pre-configured policies for publish, subscribe, and full access
- **Import Support**: Import existing SNS topics
- **Content Deduplication**: Support for content-based deduplication in FIFO topics

## Usage

### Basic Standard Topic

```yaml
version: '1.0'
flavor: standard
kind: sns_topic
spec:
  topic_config:
    display_name: My SNS Topic
  encryption_config:
    enable_encryption: true
```

### FIFO Topic with Content-Based Deduplication

```yaml
version: '1.0'
flavor: standard
kind: sns_topic
spec:
  topic_config:
    fifo_topic: true
    content_based_deduplication: true
    display_name: My FIFO Topic
  encryption_config:
    enable_encryption: true
```

### Topic with Dead Letter Queue

```yaml
version: '1.0'
flavor: standard
kind: sns_topic
spec:
  topic_config:
    display_name: My SNS Topic
  dlq_config:
    enable_dlq: true
  encryption_config:
    enable_encryption: true
```

### Topic with Custom KMS Key

```yaml
version: '1.0'
flavor: standard
kind: sns_topic
spec:
  topic_config:
    display_name: My Encrypted Topic
  encryption_config:
    enable_encryption: true
    kms_key_id: arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012
```

### Import Existing Topic

```yaml
version: '1.0'
flavor: standard
kind: sns_topic
spec:
  import_existing: true
  imports:
    topic_name: my-existing-topic
    topic_arn: arn:aws:sns:us-east-1:123456789012:my-existing-topic
```

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| cloud_account | `@facets/aws_cloud_account` | Yes | AWS Cloud Account with provider configuration |

## Outputs

The module outputs the `@facets/sns_topic` type with the following attributes:

### Attributes

| Name | Description |
|------|-------------|
| topic_name | SNS topic name |
| topic_arn | SNS topic ARN |
| dlq_queue_name | Dead letter queue name (if enabled) |
| dlq_queue_url | Dead letter queue URL (if enabled) |
| dlq_queue_arn | Dead letter queue ARN (if enabled) |
| publish_policy_arn | IAM policy ARN for publishing messages |
| subscribe_policy_arn | IAM policy ARN for subscribing to the topic |
| full_access_policy_arn | IAM policy ARN for full access |
| publish_policy_name | IAM policy name for publishing messages |
| subscribe_policy_name | IAM policy name for subscribing to the topic |
| full_access_policy_name | IAM policy name for full access |

### Interfaces

```yaml
topic:
  name: Topic name
  arn: Topic ARN
dlq:  # Only if DLQ is enabled
  name: DLQ name
  url: DLQ URL
  arn: DLQ ARN
```

## Configuration

### Topic Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| fifo_topic | boolean | false | Enable FIFO (First-In-First-Out) topic |
| content_based_deduplication | boolean | false | Enable content-based deduplication (FIFO only) |
| display_name | string | instance_name | Human-readable display name (max 100 chars) |

### Dead Letter Queue Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| enable_dlq | boolean | false | Create an SQS dead letter queue for failed deliveries |

### Encryption Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| enable_encryption | boolean | true | Enable server-side encryption |
| kms_key_id | string | null | Custom KMS key ARN (uses AWS managed key if not provided) |

## IAM Policies

The module creates three IAM policies for different access levels:

### Publish Policy
Allows publishing messages to the topic:
- `sns:Publish`
- `sns:GetTopicAttributes`

### Subscribe Policy
Allows subscribing and managing subscriptions:
- `sns:Subscribe`
- `sns:Unsubscribe`
- `sns:GetTopicAttributes`
- `sns:GetSubscriptionAttributes`
- `sns:SetSubscriptionAttributes`

### Full Access Policy
Allows all SNS operations on the topic

## Dead Letter Queue

When DLQ is enabled, an SQS queue is created to capture messages that fail delivery to subscriptions. The DLQ:
- Inherits the FIFO setting from the SNS topic
- Retains messages for 14 days
- Uses the same encryption configuration as the topic
- Has appropriate IAM policies for SNS to send messages

## Naming Convention

Topics are automatically named using the pattern:
- Standard topics: `{instance_name}-{environment.unique_name}`
- FIFO topics: `{instance_name}-{environment.unique_name}.fifo`
- Dead letter queues: `{instance_name}-{environment.unique_name}-dlq[.fifo]`

## IAM Policy Usage with IRSA

The module creates IAM policies that can be attached to Kubernetes service accounts via IRSA (IAM Roles for Service Accounts). Here's how to use them:

### Publisher Service (Send Messages)

```yaml
kind: service
flavor: aws
spec:
  cloud_permissions:
    aws:
      enable_irsa: true
      iam_policies:
        sns_publish:
          arn: "${sns_topic.my-topic.out.attributes.publish_policy_arn}"
  env:
    SNS_TOPIC_ARN: "${sns_topic.my-topic.out.attributes.topic_arn}"
```

### Subscriber Service

```yaml
kind: service
flavor: aws
spec:
  cloud_permissions:
    aws:
      enable_irsa: true
      iam_policies:
        sns_subscribe:
          arn: "${sns_topic.my-topic.out.attributes.subscribe_policy_arn}"
  env:
    SNS_TOPIC_ARN: "${sns_topic.my-topic.out.attributes.topic_arn}"
```

### Full Access Service

```yaml
kind: service
flavor: aws
spec:
  cloud_permissions:
    aws:
      enable_irsa: true
      iam_policies:
        sns_full:
          arn: "${sns_topic.my-topic.out.attributes.full_access_policy_arn}"
  env:
    SNS_TOPIC_ARN: "${sns_topic.my-topic.out.attributes.topic_arn}"
```

**Note**: When using customer-managed KMS keys, the IAM policies automatically include `kms:Decrypt` and `kms:GenerateDataKey` permissions.

## Fan-Out Pattern: SNS → Multiple SQS Queues

SNS topics can fan-out to multiple SQS queues for parallel processing:

```yaml
# SNS Topic
- name: order-events
  kind: sns_topic
  flavor: standard
  spec:
    topic_config:
      display_name: Order Events

# SQS Queue 1: Inventory Updates
- name: inventory-queue
  kind: sqs_queue
  flavor: standard
  # Subscribe this queue to SNS topic (manual subscription in AWS Console or Terraform)

# SQS Queue 2: Shipping Updates
- name: shipping-queue
  kind: sqs_queue
  flavor: standard
  # Subscribe this queue to SNS topic

# SQS Queue 3: Analytics
- name: analytics-queue
  kind: sqs_queue
  flavor: standard
  # Subscribe this queue to SNS topic
```

Each queue independently processes messages from the topic with its own retry logic and DLQ.

## Dead Letter Queue Workflow

When you enable DLQ for SNS, failed message deliveries from **all subscriptions** go to the DLQ:

1. **Publisher sends message** to SNS topic
2. **SNS delivers to all subscriptions** (SQS queues, Lambda, HTTP endpoints, etc.)
3. **Delivery fails** (queue doesn't exist, Lambda throws error, HTTP timeout)
4. **SNS retries delivery** based on subscription retry policy
5. **After all retries exhausted**, message moves to DLQ
6. **DLQ retains message** for 14 days for investigation
7. **You investigate and fix** the subscription issue
8. **Re-drive messages** from DLQ after fixing

### Monitoring DLQ

```yaml
# CloudWatch alarm configuration (pseudo-code)
metric: ApproximateNumberOfMessagesVisible
queue_name: "${sns_topic.my-topic.out.attributes.dlq_queue_name}"
threshold: > 0
action: Send alert - subscription delivery is failing
```

### Inspecting DLQ Messages

```bash
# List messages in DLQ
aws sqs receive-message \
  --queue-url "${DLQ_URL}" \
  --max-number-of-messages 10

# Messages include SNS metadata to identify failed subscription
```

## Output Reference Table

| Output Path | Type | Purpose | Example Value |
|-------------|------|---------|---------------|
| `attributes.topic_arn` | string | Publish messages, subscribe | `arn:aws:sns:us-east-1:123:topic` |
| `attributes.topic_name` | string | CloudWatch metrics | `mytopic-prod` |
| `attributes.region` | string | SDK configuration | `us-east-1` |
| `attributes.account_id` | string | Cross-account scenarios | `123456789012` |
| `attributes.is_fifo` | boolean | Topic type detection | `false` |
| `attributes.publish_policy_arn` | string | Publisher IRSA | `arn:aws:iam::123:policy/...` |
| `attributes.subscribe_policy_arn` | string | Subscriber IRSA | `arn:aws:iam::123:policy/...` |
| `attributes.full_access_policy_arn` | string | Full access IRSA | `arn:aws:iam::123:policy/...` |
| `attributes.dlq_queue_url` | string | Monitor failed deliveries | `https://sqs.../topic-dlq` |
| `interfaces.topic.arn` | string | Cloud-agnostic ARN | Same as `topic_arn` |

## Common Integration Patterns

### 1. API Gateway → SNS → Multiple Workers

```
API POST /orders → SNS Topic
                     ├─→ SQS Queue 1 → Inventory Service
                     ├─→ SQS Queue 2 → Shipping Service
                     └─→ SQS Queue 3 → Analytics Service
```

### 2. S3 Event → SNS → Fan-Out Processing

```
S3 Upload → SNS Topic
             ├─→ Lambda (Thumbnail generation)
             ├─→ SQS Queue (Virus scanning)
             └─→ Lambda (Metadata extraction)
```

### 3. Multi-Region Event Broadcasting

```
SNS Topic (us-east-1) → SNS Topic (eu-west-1)
                        → SNS Topic (ap-southeast-1)
```

## Monitoring Best Practices

### Key Metrics to Track

- **NumberOfMessagesPublished** - Messages sent to topic
- **NumberOfNotificationsDelivered** - Successful deliveries to subscriptions
- **NumberOfNotificationsFailed** - Failed deliveries (check DLQ)
- **PublishSize** - Message size distribution

### Recommended CloudWatch Alarms

```yaml
# Failed deliveries alarm
NumberOfNotificationsFailed > 0 for 5 minutes

# DLQ has messages (subscription issues)
ApproximateNumberOfMessagesVisible (DLQ) > 0
```

## Troubleshooting

### Messages Not Being Delivered

**Symptom**: Messages published to SNS but subscriptions don't receive them

**Solutions**:
1. Verify subscriptions exist and are confirmed
2. Check subscription filter policies aren't blocking messages
3. For SQS subscriptions, verify queue policies allow SNS to send
4. Check DLQ for failed deliveries
5. Review CloudWatch metrics for `NumberOfNotificationsFailed`

### Permission Denied When Publishing

**Symptom**: `AccessDenied` or `403` errors when publishing to topic

**Solutions**:
1. Verify IRSA is enabled in service module
2. Check `publish_policy_arn` is correctly wired to service
3. For KMS encryption, ensure KMS permissions are included
4. Verify IAM role trust relationship includes EKS OIDC provider

### FIFO Topic Issues

**Symptom**: Messages are out of order or duplicated

**Solutions**:
1. Ensure `fifo_topic: true` is set
2. Provide unique `MessageGroupId` for each message
3. Enable `content_based_deduplication` to avoid providing deduplication IDs
4. Ensure all subscriptions support FIFO (only SQS FIFO queues)
5. Remember FIFO has lower throughput (300 TPS, 3000 with batching)

### DLQ Filling Up

**Symptom**: Dead letter queue has many messages

**Solutions**:
1. Check CloudWatch metrics to identify which subscription is failing
2. For SQS subscriptions: verify queue exists and has correct policy
3. For Lambda subscriptions: check Lambda execution errors
4. For HTTP/S subscriptions: verify endpoint is accessible
5. Review subscription retry policies and adjust if needed

### SNS to SQS Subscription Not Working

**Symptom**: SQS queue doesn't receive messages from SNS topic

**Solutions**:
1. Verify subscription is confirmed (check SNS console)
2. Check SQS queue policy allows SNS to send (`aws:SourceArn` condition)
3. Ensure both topic and queue are in same region (or cross-region enabled)
4. For FIFO: both topic and queue must be FIFO
5. Check subscription filter policy isn't blocking messages

## Notes

- FIFO topics automatically append `.fifo` suffix to topic names
- Dead letter queues inherit the FIFO setting from the topic
- Encryption is enabled by default using AWS managed keys
- DLQ messages are retained for 14 days by default
- All resources are tagged with environment tags and custom tags
- FIFO topics support message ordering and deduplication
- The DLQ uses SQS to store failed delivery attempts from all subscriptions
- When using KMS encryption, IAM policies automatically include KMS permissions
- SNS can deliver to: SQS, Lambda, HTTP/S, email, SMS, mobile push notifications
- Message size limit: 256 KB for all protocols

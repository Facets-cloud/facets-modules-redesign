# GCP Managed Kafka Connector Module

This module creates and manages Kafka Connect connectors for GCP Managed Service for Apache Kafka with configurable tasks and restart policies.

## Features

- ✅ Create Kafka Connect connectors for data integration
- ✅ Support for any connector type (Source/Sink)
- ✅ Flexible connector configurations via `configs` parameter
- ✅ Configurable task restart policy for fault tolerance
- ✅ Support for all standard and custom connectors

## Usage

```yaml
kind: kafka_connector
flavor: gcp-msk
version: '1.0'
spec:
  connector_id: pubsub-sink-connector
  configs:
    connector.class: com.google.pubsub.kafka.sink.CloudPubSubSinkConnector
    name: pubsub-sink-connector
    tasks.max: "3"
    topics: my-topic
    cps.topic: my-pubsub-topic
    cps.project: my-gcp-project
    value.converter: org.apache.kafka.connect.storage.StringConverter
    key.converter: org.apache.kafka.connect.storage.StringConverter
  task_restart_policy:
    minimum_backoff: '60s'
    maximum_backoff: '1800s'
```

## Configuration Parameters

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `connector_id` | string | The ID to use for the connector (e.g., 'pubsub-sink', 'bigquery-sink') |
| `configs` | map(string) | Kafka connector configuration as key-value pairs |

### Optional Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `task_restart_policy` | object | Policy for restarting failed connectors/tasks |
| `task_restart_policy.minimum_backoff` | string | Minimum wait time (default: '60s') |
| `task_restart_policy.maximum_backoff` | string | Maximum wait time (default: '1800s') |

## Common Connector Configurations

All connector configurations are passed via the `configs` parameter:

### Required Connector Configs

```yaml
configs:
  connector.class: "com.example.ConnectorClass"  # Connector implementation class
  name: "my-connector"                            # Connector name
  tasks.max: "3"                                  # Number of parallel tasks
  topics: "topic1,topic2"                         # Topics to read/write (comma-separated)
```

### Converter Configurations

```yaml
configs:
  key.converter: "org.apache.kafka.connect.storage.StringConverter"
  value.converter: "org.apache.kafka.connect.json.JsonConverter"
  value.converter.schemas.enable: "false"
```

## Common Connector Types

### 1. Cloud Pub/Sub Sink Connector

Writes Kafka messages to Google Cloud Pub/Sub:

```yaml
spec:
  connector_id: pubsub-sink
  configs:
    connector.class: com.google.pubsub.kafka.sink.CloudPubSubSinkConnector
    tasks.max: "3"
    topics: orders,events
    cps.topic: my-pubsub-topic
    cps.project: my-gcp-project
    key.converter: org.apache.kafka.connect.storage.StringConverter
    value.converter: org.apache.kafka.connect.storage.StringConverter
```

### 2. BigQuery Sink Connector

Writes Kafka messages to BigQuery:

```yaml
spec:
  connector_id: bigquery-sink
  configs:
    connector.class: com.wepay.kafka.connect.bigquery.BigQuerySinkConnector
    tasks.max: "3"
    topics: user_events
    project: my-gcp-project
    datasets: my_dataset
    autoCreateTables: "true"
    key.converter: org.apache.kafka.connect.storage.StringConverter
    value.converter: org.apache.kafka.connect.json.JsonConverter
```

### 3. Cloud Storage Sink Connector

Writes Kafka messages to Google Cloud Storage:

```yaml
spec:
  connector_id: gcs-sink
  configs:
    connector.class: io.confluent.connect.gcs.GcsSinkConnector
    tasks.max: "3"
    topics: logs
    gcs.bucket.name: my-bucket
    gcs.part.size: "5242880"
    flush.size: "1000"
    storage.class: io.confluent.connect.gcs.storage.GcsStorage
    format.class: io.confluent.connect.gcs.format.json.JsonFormat
```

### 4. JDBC Source Connector

Reads data from databases into Kafka:

```yaml
spec:
  connector_id: jdbc-source
  configs:
    connector.class: io.confluent.connect.jdbc.JdbcSourceConnector
    tasks.max: "1"
    connection.url: jdbc:postgresql://host:5432/database
    connection.user: user
    connection.password: password
    table.whitelist: users,orders
    mode: incrementing
    incrementing.column.name: id
    topic.prefix: db-
```

## Task Restart Policy

Configure automatic restart behavior for failed tasks:

```yaml
task_restart_policy:
  minimum_backoff: '60s'    # Wait at least 60 seconds before retry
  maximum_backoff: '1800s'  # Wait at most 30 minutes before retry
```

**Notes:**
- Backoff increases exponentially between min and max
- Format: `{number}s` (e.g., '60s', '3.5s')
- If not specified, failed tasks won't restart automatically

## Complete Example

```yaml
kind: kafka-connector
flavor: gcp-msk
version: '1.0'
spec:
  connector_id: production-pubsub-sink
  configs:
    # Connector basics
    connector.class: com.google.pubsub.kafka.sink.CloudPubSubSinkConnector
    name: production-pubsub-sink
    tasks.max: "5"
    
    # Source topics
    topics: orders,payments,shipments
    
    # Pub/Sub destination
    cps.topic: production-events
    cps.project: my-production-project
    
    # Serialization
    key.converter: org.apache.kafka.connect.storage.StringConverter
    value.converter: org.apache.kafka.connect.json.JsonConverter
    value.converter.schemas.enable: "false"
    
    # Error handling
    errors.tolerance: all
    errors.log.enable: "true"
    errors.log.include.messages: "true"
  
  task_restart_policy:
    minimum_backoff: '120s'
    maximum_backoff: '3600s'
```

## Input Dependencies

This module requires:

1. **Kafka Connect Cluster**: Where the connector will be deployed
2. **GCP Cloud Account**: For authentication and project configuration
3. **VPC Network**: Network configuration for connectivity

```yaml
inputs:
  kafka_cluster:
    type: '@facets/gcp-msk'
    description: GCP Managed Kafka Connect cluster
```

## Outputs

The module provides the following outputs:

- `connector_id` - The connector ID
- `connector_name` - Full connector name (includes project/location/cluster path)
- `connect_cluster_id` - Parent connect cluster ID
- `location` - GCP location
- `state` - Current connector state (RUNNING, PAUSED, FAILED, etc.)
- `configs` - Applied connector configurations

## Important Notes

1. **Connector Class**: Must be available in the Kafka Connect cluster classpath
2. **Tasks**: Number of parallel tasks depends on connector type and data volume
3. **Converters**: Must match the data format (String, JSON, Avro, etc.)
4. **Topics**: Comma-separated list for multiple topics
5. **Config Values**: All config values must be strings (use quotes for numbers)

## Connector States

- `UNASSIGNED` - Not yet assigned to workers
- `RUNNING` - Active and processing data
- `PAUSED` - Temporarily stopped
- `FAILED` - Error occurred
- `RESTARTING` - Being restarted after failure
- `STOPPED` - Permanently stopped

## Reference

For more information:
- [GCP Managed Kafka Connector Resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/managed_kafka_connector)
- [Kafka Connect Documentation](https://kafka.apache.org/documentation/#connect)
- [Google Cloud Pub/Sub Connector](https://github.com/googleapis/java-pubsub-group-kafka-connector)

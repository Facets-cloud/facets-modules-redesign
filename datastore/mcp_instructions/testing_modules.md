# Testing Datastore Modules - Generic Instructions

This document provides comprehensive instructions for testing datastore modules (PostgreSQL, MySQL, Redis) deployed through Facets control plane.

## Quick Reference

| Datastore | Default Port | Auth Variable | Client Image | Special Notes |
|-----------|-------------|---------------|--------------|---------------|
| PostgreSQL | 5432 | PGPASSWORD | postgres:16 | Uses psql client |
| MySQL | 3306 | MYSQL_PWD | mysql:8.0 | Uses mysql client |
| Redis | 6379 | REDISCLI_AUTH | redis:7-alpine | Bitnami requires REDISCLI_AUTH |

**Common Issues:**
- **Redis AUTH fails with `-a` flag**: Use `REDISCLI_AUTH` environment variable instead
- **Wrong namespace**: Many deployments create their own namespace
- **Password encoding issues**: Special characters may need escaping

## Prerequisites

- kubectl configured with appropriate cluster context
- Target datastore resource deployed in the control plane
- Basic understanding of the datastore you're testing

## General Testing Workflow

### Step 1: Identify the Deployed Resource

```bash
# Search for your datastore resource across all namespaces
kubectl get all -A | grep <resource-name>

# Example patterns:
kubectl get all -A | grep postgres
kubectl get all -A | grep mysql  
kubectl get all -A | grep redis
```

### Step 2: Locate Authentication Secrets

```bash
# Find secrets related to your resource
kubectl get secrets -A | grep <resource-name>

# Get the secret details
kubectl get secret <secret-name> -o yaml

# Decode credentials (common fields to look for):
echo "<base64-encoded-password>" | base64 -d
```

### Step 3: Extract Connection Details

Common connection parameters to gather:
- **Host/Service name**: Usually `<resource-name>-<service-suffix>`
- **Port**: Database-specific (5432 for PostgreSQL, 3306 for MySQL, 6379 for Redis)
- **Username**: Often `postgres`, `root`, or `redis`
- **Password**: Decoded from secret
- **Database name**: Default or specified database

### Step 4: Create Test Pod

Create a test pod with the appropriate client image:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: <datastore>-connection-test
  namespace: default  # or appropriate namespace
spec:
  containers:
  - name: <datastore>-client
    image: <client-image>  # See specific examples below
    command: ["/bin/bash"]
    args: ["-c", "sleep 3600"]
    env:
    # Add environment variables specific to your datastore
  restartPolicy: Never
```

### Step 5: Test Connectivity

```bash
# Apply the test pod
kubectl apply -f <test-pod>.yaml

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/<pod-name> --timeout=60s

# Execute connectivity tests (see specific examples below)
kubectl exec <pod-name> -- <test-commands>
```

### Step 6: Cleanup

```bash
# Remove test resources
kubectl delete pod <pod-name>
rm <test-pod>.yaml
```

## Database-Specific Instructions

### PostgreSQL Testing

**Client Image**: `postgres:16`

**Environment Variables**:
```yaml
env:
- name: PGPASSWORD
  value: "<decoded-password>"
- name: PGHOST
  value: "<service-name>"
- name: PGPORT
  value: "5432"
- name: PGUSER
  value: "postgres"
- name: PGDATABASE
  value: "postgres"
```

**Test Commands**:
```bash
# Basic connection test
kubectl exec <pod-name> -- psql -c "SELECT version();"

# Create test database and table
kubectl exec <pod-name> -- psql -c "CREATE DATABASE test_connectivity;"
kubectl exec <pod-name> -- psql -d test_connectivity -c "CREATE TABLE test_table (id SERIAL PRIMARY KEY, message VARCHAR(100)); INSERT INTO test_table (message) VALUES ('Connection test successful'); SELECT * FROM test_table;"

# Show databases
kubectl exec <pod-name> -- psql -c "\l"
```

### MySQL Testing

**Client Image**: `mysql:8.0`

**Environment Variables**:
```yaml
env:
- name: MYSQL_PWD
  value: "<decoded-password>"
- name: MYSQL_HOST
  value: "<service-name>"
- name: MYSQL_PORT
  value: "3306"
- name: MYSQL_USER
  value: "root"
```

**Test Commands**:
```bash
# Basic connection test
kubectl exec <pod-name> -- mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -e "SELECT VERSION();"

# Create test database and table
kubectl exec <pod-name> -- mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -e "CREATE DATABASE test_connectivity;"
kubectl exec <pod-name> -- mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -D test_connectivity -e "CREATE TABLE test_table (id INT AUTO_INCREMENT PRIMARY KEY, message VARCHAR(100)); INSERT INTO test_table (message) VALUES ('Connection test successful'); SELECT * FROM test_table;"

# Show databases
kubectl exec <pod-name> -- mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -e "SHOW DATABASES;"
```

### Redis Testing

**Client Image**: `redis:7-alpine`

**Environment Variables**:
```yaml
env:
- name: REDIS_HOST
  value: "<service-name>"
- name: REDIS_PORT
  value: "6379"
- name: REDIS_PASSWORD
  value: "<decoded-password>"  # if auth is enabled
```

**Important Note for Bitnami Redis Deployments**:
Bitnami Redis images (commonly used in Helm charts) require special authentication handling. The `-a` flag often fails with authentication errors. Use the `REDISCLI_AUTH` environment variable instead.

**Test Commands**:
```bash
# Basic connection test (no auth)
kubectl exec <pod-name> -- redis-cli -h test-redis-master -p 6379 ping

# Basic connection test (with auth - Standard Redis)
kubectl exec <pod-name> -- redis-cli -h test-redis-master -p 6379 -a $REDIS_PASSWORD ping

# Basic connection test (with auth - Bitnami Redis) - RECOMMENDED
kubectl exec <pod-name> -n <namespace> -- sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -h <service-name> -p 6379 ping'

# Test key-value operations (Bitnami Redis with auth)
kubectl exec <pod-name> -n <namespace> -- sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -h <service-name> -p 6379 set test_key "Connection test successful"'
kubectl exec <pod-name> -n <namespace> -- sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -h <service-name> -p 6379 get test_key'

# Get Redis info (Bitnami Redis with auth)
kubectl exec <pod-name> -n <namespace> -- sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -h <service-name> -p 6379 info server'

# Alternative: Use environment variables directly
kubectl exec <pod-name> -n <namespace> -- sh -c 'redis-cli -h $REDIS_HOST -p $REDIS_PORT ping'  # Will use REDISCLI_AUTH from pod env
```

**Troubleshooting Redis Authentication**:
1. If you get `WRONGPASS` errors with `-a` flag, switch to `REDISCLI_AUTH` environment variable
2. Check if Redis is deployed using Bitnami images by examining the StatefulSet:
   ```bash
   kubectl describe statefulset <redis-statefulset> -n <namespace> | grep -i bitnami
   ```
3. Verify the password from within the Redis pod itself:
   ```bash
   kubectl exec <redis-pod> -n <namespace> -- sh -c 'echo $REDIS_PASSWORD'
   kubectl exec <redis-pod> -n <namespace> -- sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ping'
   ```

## Debugging and Troubleshooting

### Common Issues and Solutions

#### 1. Pod Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Common fixes:
# - Verify image name and tag
# - Check resource constraints
# - Ensure namespace exists
```

#### 2. Connection Refused/Timeout

```bash
# Verify service is running
kubectl get svc | grep <service-name>

# Check service endpoints
kubectl get endpoints <service-name>

# Verify pod is running
kubectl get pods | grep <resource-name>

# Check pod logs
kubectl logs <statefulset-pod-name>

# Test service connectivity from within cluster
kubectl run debug-pod --image=busybox --rm -it --restart=Never -- nslookup <service-name>
kubectl run debug-pod --image=busybox --rm -it --restart=Never -- telnet <service-name> <port>
```

#### 3. Authentication Issues

```bash
# Verify secret exists and is properly formatted
kubectl get secret <secret-name> -o yaml

# Check if password was properly decoded
echo "<base64-string>" | base64 -d | hexdump -C

# For MySQL, check if user has proper permissions
kubectl exec <pod-name> -- mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -e "SELECT user, host FROM mysql.user;"

# For PostgreSQL, check user permissions
kubectl exec <pod-name> -- psql -c "\du"

# For Redis (especially Bitnami), verify authentication method
# First, check if it's a Bitnami deployment
kubectl describe statefulset <redis-statefulset> -n <namespace> | grep -i bitnami

# If authentication fails with -a flag, use REDISCLI_AUTH
kubectl exec <pod-name> -n <namespace> -- sh -c 'REDISCLI_AUTH="<password>" redis-cli -h <host> ping'

# Test from within the Redis pod itself to isolate network vs auth issues
kubectl exec <redis-pod> -n <namespace> -- sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ping'
```

#### Special Note: Bitnami Deployments

Bitnami-based deployments (common in Helm charts) have specific requirements:

**PostgreSQL (Bitnami)**:
- Uses `POSTGRESQL_PASSWORD` environment variable
- Default user is typically `postgres`
- May require `PGPASSWORD` for client connections

**MySQL (Bitnami)**:
- Uses `MYSQL_ROOT_PASSWORD` or `MYSQL_PASSWORD`
- May have different authentication plugins enabled

**Redis (Bitnami)**:
- Requires `REDISCLI_AUTH` instead of `-a` flag for authentication
- Uses `REDIS_PASSWORD` environment variable
- Authentication is enforced by default (`ALLOW_EMPTY_PASSWORD=no`)

To identify Bitnami deployments:
```bash
# Check pod environment variables
kubectl exec <pod-name> -n <namespace> -- printenv | grep -i bitnami

# Check container image
kubectl describe pod <pod-name> -n <namespace> | grep -i image
```

#### 4. DNS Resolution Issues

```bash
# Test DNS resolution
kubectl exec <pod-name> -- nslookup <service-name>

# Check if using correct namespace
kubectl get svc -A | grep <service-name>

# Use FQDN if needed
<service-name>.<namespace>.svc.cluster.local
```

#### 5. Network Policies

```bash
# Check for network policies that might block traffic
kubectl get networkpolicies -A

# Describe network policy if exists
kubectl describe networkpolicy <policy-name> -n <namespace>
```

### Advanced Debugging Commands

#### Resource Investigation
```bash
# Get detailed resource information
kubectl describe pod <pod-name>
kubectl describe svc <service-name>
kubectl describe statefulset <statefulset-name>

# Check resource logs
kubectl logs <pod-name> --previous  # Previous container logs
kubectl logs <pod-name> -c <container-name>  # Specific container

# Port forward for direct testing
kubectl port-forward svc/<service-name> <local-port>:<service-port>
```

#### Environment Variable Debugging
```bash
# List all environment variables in test pod
kubectl exec <pod-name> -- printenv | sort

# Check specific environment variables
kubectl exec <pod-name> -- printenv | grep -i <pattern>
```

#### Service Discovery
```bash
# Check all services in namespace
kubectl get svc -o wide

# Get service YAML configuration
kubectl get svc <service-name> -o yaml

# Check service selector matches pod labels
kubectl get pods --show-labels | grep <resource-name>
```

## Test Validation Checklist

- [ ] Resource pods are running and ready
- [ ] Services are accessible and have endpoints
- [ ] Authentication credentials are correct
- [ ] Basic connectivity test passes
- [ ] Database/key-value operations work
- [ ] Version information is retrievable
- [ ] Test data can be created and queried
- [ ] Cleanup completed successfully

## Security Considerations

1. **Never log or expose credentials** in plain text in CI/CD logs
2. **Use kubectl exec carefully** - avoid putting passwords in command history
3. **Clean up test resources** after testing to avoid resource leaks
4. **Use least-privilege access** for test operations
5. **Rotate credentials** if they are accidentally exposed

## Example Complete Test Script

```bash
#!/bin/bash
set -e

RESOURCE_NAME="test-k8s-redis"
DATASTORE_TYPE="redis"  # postgres, mysql, or redis
NAMESPACE="default"  # Update with actual namespace

echo "Testing ${DATASTORE_TYPE} connectivity for ${RESOURCE_NAME}..."

# Step 1: Find resources
echo "Finding ${DATASTORE_TYPE} resources..."
kubectl get all -A | grep ${RESOURCE_NAME}

# Step 2: Determine namespace if not provided
if [ "$NAMESPACE" == "default" ]; then
    NAMESPACE=$(kubectl get all -A | grep ${RESOURCE_NAME} | head -1 | awk '{print $1}')
    echo "Detected namespace: ${NAMESPACE}"
fi

# Step 3: Get credentials
echo "Extracting credentials..."
SECRET_NAME=$(kubectl get secrets -n ${NAMESPACE} | grep ${RESOURCE_NAME} | grep -v helm | awk '{print $1}')

# Extract password based on datastore type
case ${DATASTORE_TYPE} in
    postgres)
        PASSWORD=$(kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -o jsonpath='{.data.postgres-password}' | base64 -d)
        SERVICE_NAME="${RESOURCE_NAME}-postgresql"
        PORT=5432
        ;;
    mysql)
        PASSWORD=$(kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -o jsonpath='{.data.mysql-root-password}' | base64 -d)
        SERVICE_NAME="${RESOURCE_NAME}-mysql"
        PORT=3306
        ;;
    redis)
        PASSWORD=$(kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -o jsonpath='{.data.redis-password}' | base64 -d)
        SERVICE_NAME="${RESOURCE_NAME}-master"
        PORT=6379
        ;;
esac

echo "Service: ${SERVICE_NAME}, Port: ${PORT}"

# Step 4: Create test pod YAML
cat > ${DATASTORE_TYPE}-test-pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${DATASTORE_TYPE}-connection-test
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: ${DATASTORE_TYPE}-client
    image: $([ "$DATASTORE_TYPE" == "postgres" ] && echo "postgres:16" || [ "$DATASTORE_TYPE" == "mysql" ] && echo "mysql:8.0" || echo "redis:7-alpine")
    command: ["/bin/sh"]
    args: ["-c", "sleep 3600"]
    env:
EOF

# Add environment variables based on datastore type
case ${DATASTORE_TYPE} in
    postgres)
        cat >> ${DATASTORE_TYPE}-test-pod.yaml <<EOF
    - name: PGPASSWORD
      value: "${PASSWORD}"
    - name: PGHOST
      value: "${SERVICE_NAME}"
    - name: PGPORT
      value: "${PORT}"
    - name: PGUSER
      value: "postgres"
    - name: PGDATABASE
      value: "postgres"
EOF
        ;;
    mysql)
        cat >> ${DATASTORE_TYPE}-test-pod.yaml <<EOF
    - name: MYSQL_PWD
      value: "${PASSWORD}"
    - name: MYSQL_HOST
      value: "${SERVICE_NAME}"
    - name: MYSQL_PORT
      value: "${PORT}"
    - name: MYSQL_USER
      value: "root"
EOF
        ;;
    redis)
        cat >> ${DATASTORE_TYPE}-test-pod.yaml <<EOF
    - name: REDIS_HOST
      value: "${SERVICE_NAME}"
    - name: REDIS_PORT
      value: "${PORT}"
    - name: REDIS_PASSWORD
      value: "${PASSWORD}"
    - name: REDISCLI_AUTH
      value: "${PASSWORD}"
EOF
        ;;
esac

cat >> ${DATASTORE_TYPE}-test-pod.yaml <<EOF
  restartPolicy: Never
EOF

# Step 5: Apply and wait for pod
echo "Creating test pod..."
kubectl apply -f ${DATASTORE_TYPE}-test-pod.yaml
kubectl wait --for=condition=ready pod/${DATASTORE_TYPE}-connection-test -n ${NAMESPACE} --timeout=60s

# Step 6: Test connectivity based on datastore type
echo "Testing connectivity..."
case ${DATASTORE_TYPE} in
    postgres)
        kubectl exec ${DATASTORE_TYPE}-connection-test -n ${NAMESPACE} -- psql -c "SELECT version();"
        ;;
    mysql)
        kubectl exec ${DATASTORE_TYPE}-connection-test -n ${NAMESPACE} -- mysql -h \$MYSQL_HOST -P \$MYSQL_PORT -u \$MYSQL_USER -e "SELECT VERSION();"
        ;;
    redis)
        # Use REDISCLI_AUTH for Bitnami Redis
        kubectl exec ${DATASTORE_TYPE}-connection-test -n ${NAMESPACE} -- sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -h $REDIS_HOST -p $REDIS_PORT ping'
        ;;
esac

# Step 7: Cleanup
echo "Cleaning up..."
kubectl delete pod ${DATASTORE_TYPE}-connection-test -n ${NAMESPACE}
rm ${DATASTORE_TYPE}-test-pod.yaml

echo "Test completed successfully!"
```

This generic framework can be customized for specific datastore modules while maintaining consistency across different database types.
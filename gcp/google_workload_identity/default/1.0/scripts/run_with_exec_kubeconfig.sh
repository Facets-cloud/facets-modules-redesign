#!/bin/bash

# Script to run kubectl commands with exec-based authentication from GKE
# This script creates a temporary kubeconfig with exec authentication
# and runs the provided kubectl command

set -euo pipefail

# Check required environment variables
if [[ -z "${CLUSTER_ENDPOINT:-}" ]]; then
    echo "Error: CLUSTER_ENDPOINT environment variable is required" >&2
    exit 1
fi

if [[ -z "${CLUSTER_CA_CERT:-}" ]]; then
    echo "Error: CLUSTER_CA_CERT environment variable is required" >&2
    exit 1
fi

if [[ -z "${EXEC_API_VERSION:-}" ]]; then
    echo "Error: EXEC_API_VERSION environment variable is required" >&2
    exit 1
fi

if [[ -z "${EXEC_COMMAND:-}" ]]; then
    echo "Error: EXEC_COMMAND environment variable is required" >&2
    exit 1
fi

if [[ -z "${EXEC_ARGS:-}" ]]; then
    echo "Error: EXEC_ARGS environment variable is required" >&2
    exit 1
fi

# Parse EXEC_ARGS from JSON array string to bash array
readarray -t exec_args_array < <(echo "$EXEC_ARGS" | jq -r '.[]')

# Create temporary kubeconfig file
KUBECONFIG_FILE=$(mktemp)
trap "rm -f $KUBECONFIG_FILE" EXIT

# Write kubeconfig with exec authentication
cat > "$KUBECONFIG_FILE" << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $CLUSTER_CA_CERT
    server: $CLUSTER_ENDPOINT
  name: gke-cluster
contexts:
- context:
    cluster: gke-cluster
    user: gke-user
  name: gke-context
current-context: gke-context
users:
- name: gke-user
  user:
    exec:
      apiVersion: $EXEC_API_VERSION
      command: $EXEC_COMMAND
EOF

# Add exec args to kubeconfig
if [[ ${#exec_args_array[@]} -gt 0 ]]; then
    echo "      args:" >> "$KUBECONFIG_FILE"
    for arg in "${exec_args_array[@]}"; do
        echo "      - \"$arg\"" >> "$KUBECONFIG_FILE"
    done
fi

# Export the kubeconfig and run the command
export KUBECONFIG="$KUBECONFIG_FILE"

# Execute the provided command
exec "$@"
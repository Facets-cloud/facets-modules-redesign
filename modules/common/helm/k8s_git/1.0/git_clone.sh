#!/bin/bash
set -e

# Check if jq is available
if ! command -v jq &> /dev/null; then
    >&2 echo "Error: jq command not found. Please install jq to run this script."
    exit 1
fi

# Check if git is available
if ! command -v git &> /dev/null; then
    >&2 echo "Error: git command not found. Please install git to run this script."
    exit 1
fi

# Parse JSON input from Terraform
if ! eval "$(jq -r '@sh "
GIT_URL=\(.git_url)
GIT_REF=\(.git_ref)
CHART_DIR=\(.chart_dir)
CHART_PATH=\(.chart_path)
"')" 2>/dev/null; then
    >&2 echo "Error: Failed to parse JSON input from Terraform"
    exit 1
fi

# Validate required environment variables
if [ -z "$GIT_URL" ]; then
    >&2 echo "Error: GIT_URL is required but not provided"
    exit 1
fi

if [ -z "$GIT_REF" ]; then
    >&2 echo "Error: GIT_REF is required but not provided"
    exit 1
fi

if [ -z "$CHART_DIR" ]; then
    >&2 echo "Error: CHART_DIR is required but not provided"
    exit 1
fi

# Clean up existing directory
if ! rm -rf "$CHART_DIR" 2>/dev/null; then
    >&2 echo "Error: Failed to remove existing directory $CHART_DIR"
    exit 1
fi

if ! mkdir -p "$CHART_DIR" 2>/dev/null; then
    >&2 echo "Error: Failed to create directory $CHART_DIR"
    exit 1
fi

# Initialize git repository
if ! cd "$CHART_DIR" 2>/dev/null; then
    >&2 echo "Error: Failed to change to directory $CHART_DIR"
    exit 1
fi

if ! git init >/dev/null 2>&1; then
    >&2 echo "Error: Failed to initialize git repository in $CHART_DIR"
    >&2 echo "Git init output:"
    git init 2>&1 | >&2 cat || true
    exit 1
fi

if ! git remote add origin "$GIT_URL" 2>/dev/null; then
    >&2 echo "Error: Failed to add git remote origin $GIT_URL"
    >&2 echo "Git remote add output:"
    git remote add origin "$GIT_URL" 2>&1 | >&2 cat || true
    exit 1
fi

# Configure sparse checkout
if ! git config core.sparseCheckout true 2>/dev/null; then
    >&2 echo "Error: Failed to configure sparse checkout"
    git config core.sparseCheckout true 2>&1 | >&2 cat || true
    exit 1
fi

# Set sparse checkout pattern
if [ -n "$CHART_PATH" ]; then
  if ! echo "$CHART_PATH/*" > .git/info/sparse-checkout 2>/dev/null; then
    >&2 echo "Error: Failed to write sparse-checkout pattern for $CHART_PATH"
    exit 1
  fi
  FULL_CHART_PATH="$CHART_PATH"
else
  if ! echo "/*" > .git/info/sparse-checkout 2>/dev/null; then
    >&2 echo "Error: Failed to write sparse-checkout pattern for root"
    exit 1
  fi
  FULL_CHART_PATH="."
fi

# Pull only the specific path with depth 1
if ! git pull --depth=1 origin "$GIT_REF" >/dev/null 2>&1; then
    >&2 echo "Error: Failed to pull from git repository"
    >&2 echo "Git URL: $GIT_URL"
    >&2 echo "Git REF: $GIT_REF"
    >&2 echo "Git pull output:"
    git pull --depth=1 origin "$GIT_REF" 2>&1 | >&2 cat || true
    exit 1
fi

# Verify chart exists
if [ ! -f "$FULL_CHART_PATH/Chart.yaml" ] && [ ! -f "$FULL_CHART_PATH/Chart.yml" ]; then
  echo "Error: Chart.yaml not found in $FULL_CHART_PATH" >&2
  echo "Available files/directories:" >&2
  if [ -d "$FULL_CHART_PATH" ]; then
    ls -la "$FULL_CHART_PATH" >&2
  else
    echo "Directory $FULL_CHART_PATH does not exist" >&2
    echo "Repository contents:" >&2
    find "$CHART_DIR" -type f -name "*.yaml" -o -name "*.yml" | head -10 >&2
  fi
  exit 1
fi

CHART_VERSION=$(awk '/^version:/ {print $2}' "$FULL_CHART_PATH/Chart.yaml" 2>/dev/null)

# Return JSON with chart information
ABSOLUTE_FULL_CHART_PATH=$(realpath "$FULL_CHART_PATH")
jq -n \
  --arg chart_path "$ABSOLUTE_FULL_CHART_PATH" \
  --arg chart_version "$CHART_VERSION" \
  '{
    chart_path: $chart_path,
    chart_version: $chart_version
  }' || {
    >&2 echo "Error: Failed to generate JSON output"
    exit 1
}

locals {
  output_attributes = {
    # Cluster identification
    cluster_id       = google_container_cluster.primary.id
    cluster_name     = google_container_cluster.primary.name
    cluster_location = google_container_cluster.primary.location
    cluster_version  = google_container_cluster.primary.master_version

    # Authentication - standard names matching EKS/AKS
    cluster_endpoint       = "https://${google_container_cluster.primary.endpoint}"
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
    kubernetes_provider_exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "bash"
      args = [
        "-c",
        <<-BASH
        set -euo pipefail

        # Check and install required tools
        REQUIRED_TOOLS="jq openssl curl"
        MISSING_TOOLS=""

        for tool in $REQUIRED_TOOLS; do
          if ! command -v $tool >/dev/null 2>&1; then
            MISSING_TOOLS="$MISSING_TOOLS $tool"
          fi
        done

        if [[ -n "$MISSING_TOOLS" ]]; then
          echo "Installing missing tools:$MISSING_TOOLS" >&2

          # Detect package manager and install
          if command -v apt-get >/dev/null 2>&1; then
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq >/dev/null 2>&1 || true
            for tool in $MISSING_TOOLS; do
              case $tool in
                openssl) apt-get install -qq -y openssl >/dev/null 2>&1 || echo "Warning: Failed to install openssl" >&2 ;;
                jq) apt-get install -qq -y jq >/dev/null 2>&1 || echo "Warning: Failed to install jq" >&2 ;;
                curl) apt-get install -qq -y curl >/dev/null 2>&1 || echo "Warning: Failed to install curl" >&2 ;;
              esac
            done
          elif command -v yum >/dev/null 2>&1; then
            for tool in $MISSING_TOOLS; do
              yum install -q -y $tool >/dev/null 2>&1 || echo "Warning: Failed to install $tool" >&2
            done
          elif command -v apk >/dev/null 2>&1; then
            apk add --no-cache $MISSING_TOOLS >/dev/null 2>&1 || echo "Warning: Failed to install tools" >&2
          else
            echo "Error: No supported package manager found (apt-get/yum/apk)" >&2
            echo "Please install manually:$MISSING_TOOLS" >&2
            exit 1
          fi

          # Verify installation
          for tool in $MISSING_TOOLS; do
            if ! command -v $tool >/dev/null 2>&1; then
              echo "Error: Failed to install required tool '$tool'" >&2
              exit 1
            fi
          done
          echo "Successfully installed:$MISSING_TOOLS" >&2
        fi

        # Create temp file with secure permissions
        CREDS_FILE=$(mktemp /tmp/gcp-creds-XXXXXX.json)
        chmod 600 "$CREDS_FILE"

        # Ensure cleanup on exit
        trap "rm -f '$CREDS_FILE'" EXIT

        # Write credentials to temp file
        echo '${local.credentials}' > "$CREDS_FILE"

        # Read service account key
        SA_EMAIL=$(jq -r .client_email "$CREDS_FILE")
        PRIVATE_KEY=$(jq -r .private_key "$CREDS_FILE")

        # Validate extracted values
        if [[ -z "$SA_EMAIL" || "$SA_EMAIL" == "null" ]]; then
          echo "Error: Failed to extract service account email" >&2
          exit 1
        fi
        if [[ -z "$PRIVATE_KEY" || "$PRIVATE_KEY" == "null" ]]; then
          echo "Error: Failed to extract private key" >&2
          exit 1
        fi

        # Create JWT
        NOW=$(date +%s)
        EXP=$((NOW + 3600))

        HEADER='{"alg":"RS256","typ":"JWT"}'
        CLAIM="{\"iss\":\"$SA_EMAIL\",\"scope\":\"https://www.googleapis.com/auth/cloud-platform\",\"aud\":\"https://oauth2.googleapis.com/token\",\"exp\":$EXP,\"iat\":$NOW}"

        # Base64 encode (URL-safe)
        b64enc() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }

        HEADER_B64=$(echo -n "$HEADER" | b64enc)
        CLAIM_B64=$(echo -n "$CLAIM" | b64enc)
        SIGNATURE=$(printf "%s.%s" "$HEADER_B64" "$CLAIM_B64" | openssl dgst -sha256 -sign <(echo "$PRIVATE_KEY") -binary | b64enc)

        JWT="$HEADER_B64.$CLAIM_B64.$SIGNATURE"

        # Get token with error handling
        RESPONSE=$(curl -s -w "\n%%{http_code}" -X POST https://oauth2.googleapis.com/token \
          -H "Content-Type: application/x-www-form-urlencoded" \
          -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$JWT")

        HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
        BODY=$(echo "$RESPONSE" | head -n-1)

        if [[ "$HTTP_CODE" != "200" ]]; then
          echo "Error: OAuth token request failed with HTTP $HTTP_CODE" >&2
          echo "$BODY" >&2
          exit 1
        fi

        TOKEN=$(echo "$BODY" | jq -r .access_token)

        if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
          echo "Error: Failed to extract access token from response" >&2
          echo "$BODY" >&2
          exit 1
        fi

        # Output kubectl format
        cat <<JSON
        {
          "apiVersion": "client.authentication.k8s.io/v1beta1",
          "kind": "ExecCredential",
          "status": {
            "token": "$TOKEN"
          }
        }
        JSON
        BASH
      ]
    }

    # Project and region details
    project_id = local.project_id
    region     = local.region

    # Network configuration
    network             = local.network
    subnetwork          = local.subnetwork
    pods_range_name     = local.pods_range_name
    services_range_name = local.services_range_name

    # Cluster settings
    auto_upgrade    = local.auto_upgrade
    release_channel = local.release_channel

    # Additional cluster details
    cluster_ipv4_cidr = google_container_cluster.primary.cluster_ipv4_cidr

    # Master auth (additional fields if needed)
    master_authorized_networks_config = local.whitelisted_cidrs

    # Workload identity
    workload_identity_config_workload_pool = "${local.project_id}.svc.id.goog"

    # Maintenance window
    maintenance_policy_enabled = local.auto_upgrade

    cloud_provider = "GCP"

    secrets = "[\"cluster_ca_certificate\"]"

  }

  output_interfaces = {
    kubernetes = {
      host                   = "https://${google_container_cluster.primary.endpoint}"
      cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
      exec = {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "bash"
        args = [
          "-c",
          <<-BASH
          set -euo pipefail

          # Check and install required tools
          REQUIRED_TOOLS="jq openssl curl"
          MISSING_TOOLS=""

          for tool in $REQUIRED_TOOLS; do
            if ! command -v $tool >/dev/null 2>&1; then
              MISSING_TOOLS="$MISSING_TOOLS $tool"
            fi
          done

          if [[ -n "$MISSING_TOOLS" ]]; then
            echo "Installing missing tools:$MISSING_TOOLS" >&2

            # Detect package manager and install
            if command -v apt-get >/dev/null 2>&1; then
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -qq >/dev/null 2>&1 || true
              for tool in $MISSING_TOOLS; do
                case $tool in
                  openssl) apt-get install -qq -y openssl >/dev/null 2>&1 || echo "Warning: Failed to install openssl" >&2 ;;
                  jq) apt-get install -qq -y jq >/dev/null 2>&1 || echo "Warning: Failed to install jq" >&2 ;;
                  curl) apt-get install -qq -y curl >/dev/null 2>&1 || echo "Warning: Failed to install curl" >&2 ;;
                esac
              done
            elif command -v yum >/dev/null 2>&1; then
              for tool in $MISSING_TOOLS; do
                yum install -q -y $tool >/dev/null 2>&1 || echo "Warning: Failed to install $tool" >&2
              done
            elif command -v apk >/dev/null 2>&1; then
              apk add --no-cache $MISSING_TOOLS >/dev/null 2>&1 || echo "Warning: Failed to install tools" >&2
            else
              echo "Error: No supported package manager found (apt-get/yum/apk)" >&2
              echo "Please install manually:$MISSING_TOOLS" >&2
              exit 1
            fi

            # Verify installation
            for tool in $MISSING_TOOLS; do
              if ! command -v $tool >/dev/null 2>&1; then
                echo "Error: Failed to install required tool '$tool'" >&2
                exit 1
              fi
            done
            echo "Successfully installed:$MISSING_TOOLS" >&2
          fi

          # Create temp file with secure permissions
          CREDS_FILE=$(mktemp /tmp/gcp-creds-XXXXXX.json)
          chmod 600 "$CREDS_FILE"

          # Ensure cleanup on exit
          trap "rm -f '$CREDS_FILE'" EXIT

          # Write credentials to temp file
          echo '${local.credentials}' > "$CREDS_FILE"

          # Read service account key
          SA_EMAIL=$(jq -r .client_email "$CREDS_FILE")
          PRIVATE_KEY=$(jq -r .private_key "$CREDS_FILE")

          # Validate extracted values
          if [[ -z "$SA_EMAIL" || "$SA_EMAIL" == "null" ]]; then
            echo "Error: Failed to extract service account email" >&2
            exit 1
          fi
          if [[ -z "$PRIVATE_KEY" || "$PRIVATE_KEY" == "null" ]]; then
            echo "Error: Failed to extract private key" >&2
            exit 1
          fi

          # Create JWT
          NOW=$(date +%s)
          EXP=$((NOW + 3600))

          HEADER='{"alg":"RS256","typ":"JWT"}'
          CLAIM="{\"iss\":\"$SA_EMAIL\",\"scope\":\"https://www.googleapis.com/auth/cloud-platform\",\"aud\":\"https://oauth2.googleapis.com/token\",\"exp\":$EXP,\"iat\":$NOW}"

          # Base64 encode (URL-safe)
          b64enc() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }

          HEADER_B64=$(echo -n "$HEADER" | b64enc)
          CLAIM_B64=$(echo -n "$CLAIM" | b64enc)
          SIGNATURE=$(printf "%s.%s" "$HEADER_B64" "$CLAIM_B64" | openssl dgst -sha256 -sign <(echo "$PRIVATE_KEY") -binary | b64enc)

          JWT="$HEADER_B64.$CLAIM_B64.$SIGNATURE"

          # Get token with error handling
          RESPONSE=$(curl -s -w "\n%%{http_code}" -X POST https://oauth2.googleapis.com/token \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$JWT")

          HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
          BODY=$(echo "$RESPONSE" | head -n-1)

          if [[ "$HTTP_CODE" != "200" ]]; then
            echo "Error: OAuth token request failed with HTTP $HTTP_CODE" >&2
            echo "$BODY" >&2
            exit 1
          fi

          TOKEN=$(echo "$BODY" | jq -r .access_token)

          if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
            echo "Error: Failed to extract access token from response" >&2
            echo "$BODY" >&2
            exit 1
          fi

          # Output kubectl format
          cat <<JSON
          {
            "apiVersion": "client.authentication.k8s.io/v1beta1",
            "kind": "ExecCredential",
            "status": {
              "token": "$TOKEN"
            }
          }
          JSON
          BASH
        ]
      }
      secrets = "[\"cluster_ca_certificate\"]"
    }
  }
}

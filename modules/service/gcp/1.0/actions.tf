locals {
  actions_required_vars_set = can(var.instance.kind) && can(var.instance.version) && can(var.instance.flavor) && !contains(["cronjob", "job"], local.spec_type)

  enable_actions             = lookup(var.instance.spec, "enable_actions", true) && local.actions_required_vars_set ? true : false
  enable_deployment_actions  = local.enable_actions && local.spec_type == "application" ? 1 : 0
  enable_statefulset_actions = local.enable_actions && local.spec_type == "statefulset" ? 1 : 0
}

# Deployment Actions
resource "facets_tekton_action_kubernetes" "rollout_restart_deployment" {
  count = local.enable_deployment_actions
  name  = "rollout-restart-${local.spec_type}"

  facets_resource_name = var.instance_name
  facets_environment   = var.environment
  facets_resource      = var.instance

  description = "This task performs a rollout restart of Kubernetes deployments based on labels."
  steps = [
    {
      name  = "restart-deployments"
      image = "bitnamilegacy/kubectl:1.33.4"
      env = [
        {
          name  = "RESOURCE_TYPE"
          value = local.resource_type
        },
        {
          name  = "RESOURCE_NAME"
          value = local.resource_name
        },
        {
          name  = "NAMESPACE"
          value = local.namespace
        }
      ]
      script = <<-EOT
        #!/bin/bash
        set -e
        echo "Starting Kubernetes deployment rollout restart workflow..."
        echo "Resource Type: $RESOURCE_TYPE"
        echo "Resource Name: $RESOURCE_NAME"

        # Define label selector
        LABEL_SELECTOR="resourceType=$RESOURCE_TYPE,resourceName=$RESOURCE_NAME"
        echo "Label selector: $LABEL_SELECTOR"

        # Find deployments with matching labels
        DEPLOYMENTS=$(kubectl get deployments -n $NAMESPACE -l "$LABEL_SELECTOR" -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}')

        if [ -z "$DEPLOYMENTS" ]; then
          echo "No deployments found with labels: $LABEL_SELECTOR"
          exit 0
        fi

        echo "Found deployments:"
        echo "$DEPLOYMENTS"

        echo "Performing rollout restart for deployments..."
        while IFS= read -r deployment; do
          if [ -n "$deployment" ]; then
            namespace=$NAMESPACE
            name=$(echo "$deployment" | cut -d'/' -f2)
            echo "Restarting deployment: $name in namespace: $namespace"

            kubectl rollout restart deployment "$name" -n "$namespace"
            if [ $? -eq 0 ]; then
              echo "Rollout restart initiated for $name"
              echo "Waiting for rollout to complete..."
              kubectl rollout status deployment "$name" -n "$namespace" --timeout=300s
              if [ $? -eq 0 ]; then
                echo "Rollout completed successfully for $name"
              else
                echo "Rollout timeout or failed for $name"
                exit 1
              fi
            else
              echo "Failed to initiate rollout restart for $name"
              exit 1
            fi
          fi
        done <<< "$DEPLOYMENTS"
        echo "All deployments restarted successfully."
      EOT
    }
  ]
}

resource "facets_tekton_action_kubernetes" "scale_down_deployment" {
  count = local.enable_deployment_actions
  name  = "scale-down-${local.spec_type}"

  facets_resource_name = var.instance_name
  facets_environment   = var.environment
  facets_resource      = var.instance

  description = "This task scales down Kubernetes service to 0 replicas based on labels."
  steps = [
    {
      name  = "scale-down-service"
      image = "bitnamilegacy/kubectl:1.33.4"
      env = [
        {
          name  = "RESOURCE_TYPE"
          value = local.resource_type
        },
        {
          name  = "RESOURCE_NAME"
          value = local.resource_name
        },
        {
          name  = "NAMESPACE"
          value = local.namespace
        }
      ]
      script = <<-EOT
        #!/bin/bash
        set -e
        echo "Starting Kubernetes deployment scale down workflow..."
        echo "Resource Type: $RESOURCE_TYPE"
        echo "Resource Name: $RESOURCE_NAME"

        # Define label selector
        LABEL_SELECTOR="resourceType=$RESOURCE_TYPE,resourceName=$RESOURCE_NAME"
        echo "Label selector: $LABEL_SELECTOR"

        # Find deployments with matching labels
        DEPLOYMENTS=$(kubectl get deployments -n $NAMESPACE -l "$LABEL_SELECTOR" -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}')

        if [ -z "$DEPLOYMENTS" ]; then
          echo "No deployments found with labels: $LABEL_SELECTOR"
          exit 0
        fi

        echo "Found deployments:"
        echo "$DEPLOYMENTS"

        echo "Scaling down deployments to 0 replicas..."
        while IFS= read -r deployment; do
          if [ -n "$deployment" ]; then
            namespace=$NAMESPACE
            name=$(echo "$deployment" | cut -d'/' -f2)
            echo "Processing deployment: $name in namespace: $namespace"

            # Get current replica count
            CURRENT_REPLICAS=$(kubectl get deployment "$name" -n "$namespace" -o jsonpath='{.spec.replicas}')
            echo "Current replicas for $name: $CURRENT_REPLICAS"

            # Store original replica count as annotation
            kubectl annotate deployment "$name" -n "$namespace" "workflow.facets.cloud/original-replicas=$CURRENT_REPLICAS" --overwrite
            if [ $? -eq 0 ]; then
              echo "Stored original replica count ($CURRENT_REPLICAS) for $name"
            else
              echo "Failed to store original replica count for $name"
              exit 1
            fi

            # Scale down to 0 replicas
            kubectl scale deployment "$name" -n "$namespace" --replicas=0
            if [ $? -eq 0 ]; then
              echo "Deployment $name scaled down to 0 replicas"
            else
              echo "Failed to scale down deployment $name"
              exit 1
            fi
          fi
        done <<< "$DEPLOYMENTS"
        echo "All deployments scaled down successfully."
      EOT
    }
  ]
}

resource "facets_tekton_action_kubernetes" "scale_up_deployment" {
  count = local.enable_deployment_actions
  name  = "scale-up-${local.spec_type}"

  facets_resource_name = var.instance_name
  facets_environment   = var.environment
  facets_resource      = var.instance

  description = "This task scales up Kubernetes deployments to their original replica count based on stored annotation."
  steps = [
    {
      name  = "scale-up-deployments"
      image = "bitnamilegacy/kubectl:1.33.4"
      env = [
        {
          name  = "RESOURCE_TYPE"
          value = local.resource_type
        },
        {
          name  = "RESOURCE_NAME"
          value = local.resource_name
        },
        {
          name  = "NAMESPACE"
          value = local.namespace
        }
      ]
      script = <<-EOT
        #!/bin/bash
        set -e
        echo "Starting Kubernetes deployment scale up workflow..."
        echo "Resource Type: $RESOURCE_TYPE"
        echo "Resource Name: $RESOURCE_NAME"

        # Define label selector
        LABEL_SELECTOR="resourceType=$RESOURCE_TYPE,resourceName=$RESOURCE_NAME"
        echo "Label selector: $LABEL_SELECTOR"

        # Find deployments with matching labels
        DEPLOYMENTS=$(kubectl get deployments -n $NAMESPACE -l "$LABEL_SELECTOR" -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}')

        if [ -z "$DEPLOYMENTS" ]; then
          echo "No deployments found with labels: $LABEL_SELECTOR"
          exit 0
        fi

        echo "Found deployments:"
        echo "$DEPLOYMENTS"

        echo "Scaling up deployments to original replica count..."
        while IFS= read -r deployment; do
          if [ -n "$deployment" ]; then
            namespace=$NAMESPACE
            name=$(echo "$deployment" | cut -d'/' -f2)
            echo "Processing deployment: $name in namespace: $namespace"

            # Get original replica count from annotation
            ORIGINAL_REPLICAS=$(kubectl get deployment "$name" -n "$namespace" -o jsonpath='{.metadata.annotations.workflow\.facets\.cloud/original-replicas}')

            if [ -z "$ORIGINAL_REPLICAS" ]; then
              echo "No original replica count annotation found for $name. Skipping scale up - don't know what count to scale up to."
              continue
            fi

            echo "Original replicas for $name: $ORIGINAL_REPLICAS"

            # Scale up to original replica count
            kubectl scale deployment "$name" -n "$namespace" --replicas="$ORIGINAL_REPLICAS"
            if [ $? -eq 0 ]; then
              echo "Deployment $name scaled up to $ORIGINAL_REPLICAS replicas"

              # Remove the annotation after successful scale up
              kubectl annotate deployment "$name" -n "$namespace" "workflow.facets.cloud/original-replicas-"
              if [ $? -eq 0 ]; then
                echo "Removed original replica count annotation for $name"
              else
                echo "Warning: Failed to remove original replica count annotation for $name"
              fi
            else
              echo "Failed to scale up deployment $name"
              exit 1
            fi
          fi
        done <<< "$DEPLOYMENTS"
      EOT
    }
  ]
}

# StatefulSet Actions
resource "facets_tekton_action_kubernetes" "rollout_restart_statefulset" {
  count = local.enable_statefulset_actions
  name  = "rollout-restart-${local.spec_type}"

  facets_resource_name = var.instance_name
  facets_environment   = var.environment
  facets_resource      = var.instance

  description = "This task performs a rollout restart of Kubernetes statefulsets based on labels."
  steps = [
    {
      name  = "restart-statefulsets"
      image = "bitnamilegacy/kubectl:1.33.4"
      env = [
        {
          name  = "RESOURCE_TYPE"
          value = local.resource_type
        },
        {
          name  = "RESOURCE_NAME"
          value = local.resource_name
        },
        {
          name  = "NAMESPACE"
          value = local.namespace
        }
      ]
      script = <<-EOT
        #!/bin/bash
        set -e
        echo "Starting Kubernetes statefulset rollout restart workflow..."
        echo "Resource Type: $RESOURCE_TYPE"
        echo "Resource Name: $RESOURCE_NAME"

        # Define label selector
        LABEL_SELECTOR="resourceType=$RESOURCE_TYPE,resourceName=$RESOURCE_NAME"
        echo "Label selector: $LABEL_SELECTOR"

        # Find statefulsets with matching labels
        STATEFULSETS=$(kubectl get statefulsets -n $NAMESPACE -l "$LABEL_SELECTOR" -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}')

        if [ -z "$STATEFULSETS" ]; then
          echo "No statefulsets found with labels: $LABEL_SELECTOR"
          exit 0
        fi

        echo "Found statefulsets:"
        echo "$STATEFULSETS"

        echo "Performing rollout restart for statefulsets..."
        while IFS= read -r statefulset; do
          if [ -n "$statefulset" ]; then
            namespace=$NAMESPACE
            name=$(echo "$statefulset" | cut -d'/' -f2)
            echo "Restarting statefulset: $name in namespace: $namespace"

            kubectl rollout restart statefulset "$name" -n "$namespace"
            if [ $? -eq 0 ]; then
              echo "Rollout restart initiated for $name"
              echo "Waiting for rollout to complete..."
              kubectl rollout status statefulset "$name" -n "$namespace" --timeout=300s
              if [ $? -eq 0 ]; then
                echo "Rollout completed successfully for $name"
              else
                echo "Rollout timeout or failed for $name"
                exit 1
              fi
            else
              echo "Failed to initiate rollout restart for $name"
              exit 1
            fi
          fi
        done <<< "$STATEFULSETS"
        echo "All statefulsets restarted successfully."
      EOT
    }
  ]
}

resource "facets_tekton_action_kubernetes" "scale_down_statefulset" {
  count = local.enable_statefulset_actions
  name  = "scale-down-${local.spec_type}"

  facets_resource_name = var.instance_name
  facets_environment   = var.environment
  facets_resource      = var.instance

  description = "This task scales down Kubernetes statefulsets to 0 replicas based on labels."
  steps = [
    {
      name  = "scale-down-statefulsets"
      image = "bitnamilegacy/kubectl:1.33.4"
      env = [
        {
          name  = "RESOURCE_TYPE"
          value = local.resource_type
        },
        {
          name  = "RESOURCE_NAME"
          value = local.resource_name
        },
        {
          name  = "NAMESPACE"
          value = local.namespace
        }
      ]
      script = <<-EOT
        #!/bin/bash
        set -e
        echo "Starting Kubernetes statefulset scale down workflow..."
        echo "Resource Type: $RESOURCE_TYPE"
        echo "Resource Name: $RESOURCE_NAME"

        # Define label selector
        LABEL_SELECTOR="resourceType=$RESOURCE_TYPE,resourceName=$RESOURCE_NAME"
        echo "Label selector: $LABEL_SELECTOR"

        # Find statefulsets with matching labels
        STATEFULSETS=$(kubectl get statefulsets -n $NAMESPACE -l "$LABEL_SELECTOR" -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}')

        if [ -z "$STATEFULSETS" ]; then
          echo "No statefulsets found with labels: $LABEL_SELECTOR"
          exit 0
        fi

        echo "Found statefulsets:"
        echo "$STATEFULSETS"

        echo "Scaling down statefulsets to 0 replicas..."
        while IFS= read -r statefulset; do
          if [ -n "$statefulset" ]; then
            namespace=$NAMESPACE
            name=$(echo "$statefulset" | cut -d'/' -f2)
            echo "Processing statefulset: $name in namespace: $namespace"

            # Get current replica count
            CURRENT_REPLICAS=$(kubectl get statefulset "$name" -n "$namespace" -o jsonpath='{.spec.replicas}')
            echo "Current replicas for $name: $CURRENT_REPLICAS"

            # Store original replica count as annotation
            kubectl annotate statefulset "$name" -n "$namespace" "workflow.facets.cloud/original-replicas=$CURRENT_REPLICAS" --overwrite
            if [ $? -eq 0 ]; then
              echo "Stored original replica count ($CURRENT_REPLICAS) for $name"
            else
              echo "Failed to store original replica count for $name"
              exit 1
            fi

            # Scale down to 0 replicas
            kubectl scale statefulset "$name" -n "$namespace" --replicas=0
            if [ $? -eq 0 ]; then
              echo "StatefulSet $name scaled down to 0 replicas"
            else
              echo "Failed to scale down statefulset $name"
              exit 1
            fi
          fi
        done <<< "$STATEFULSETS"
        echo "All statefulsets scaled down successfully."
      EOT
    }
  ]
}

resource "facets_tekton_action_kubernetes" "scale_up_statefulset" {
  count = local.enable_statefulset_actions
  name  = "scale-up-${local.spec_type}"

  facets_resource_name = var.instance_name
  facets_environment   = var.environment
  facets_resource      = var.instance

  description = "This task scales up Kubernetes statefulsets to their original replica count based on stored annotation."
  steps = [
    {
      name  = "scale-up-statefulsets"
      image = "bitnamilegacy/kubectl:1.33.4"
      env = [
        {
          name  = "RESOURCE_TYPE"
          value = local.resource_type
        },
        {
          name  = "RESOURCE_NAME"
          value = local.resource_name
        },
        {
          name  = "NAMESPACE"
          value = local.namespace
        }
      ]
      script = <<-EOT
        #!/bin/bash
        set -e
        echo "Starting Kubernetes statefulset scale up workflow..."
        echo "Resource Type: $RESOURCE_TYPE"
        echo "Resource Name: $RESOURCE_NAME"

        # Define label selector
        LABEL_SELECTOR="resourceType=$RESOURCE_TYPE,resourceName=$RESOURCE_NAME"
        echo "Label selector: $LABEL_SELECTOR"

        # Find statefulsets with matching labels
        STATEFULSETS=$(kubectl get statefulsets -n $NAMESPACE -l "$LABEL_SELECTOR" -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}')

        if [ -z "$STATEFULSETS" ]; then
          echo "No statefulsets found with labels: $LABEL_SELECTOR"
          exit 0
        fi

        echo "Found statefulsets:"
        echo "$STATEFULSETS"

        echo "Scaling up statefulsets to original replica count..."
        while IFS= read -r statefulset; do
          if [ -n "$statefulset" ]; then
            namespace=$NAMESPACE
            name=$(echo "$statefulset" | cut -d'/' -f2)
            echo "Processing statefulset: $name in namespace: $namespace"

            # Get original replica count from annotation
            ORIGINAL_REPLICAS=$(kubectl get statefulset "$name" -n "$namespace" -o jsonpath='{.metadata.annotations.workflow\.facets\.cloud/original-replicas}')

            if [ -z "$ORIGINAL_REPLICAS" ]; then
              echo "No original replica count annotation found for $name. Skipping scale up - don't know what count to scale up to."
              continue
            fi

            echo "Original replicas for $name: $ORIGINAL_REPLICAS"

            # Scale up to original replica count
            kubectl scale statefulset "$name" -n "$namespace" --replicas="$ORIGINAL_REPLICAS"
            if [ $? -eq 0 ]; then
              echo "StatefulSet $name scaled up to $ORIGINAL_REPLICAS replicas"

              # Remove the annotation after successful scale up
              kubectl annotate statefulset "$name" -n "$namespace" "workflow.facets.cloud/original-replicas-"
              if [ $? -eq 0 ]; then
                echo "Removed original replica count annotation for $name"
              else
                echo "Warning: Failed to remove original replica count annotation for $name"
              fi
            else
              echo "Failed to scale up statefulset $name"
              exit 1
            fi
          fi
        done <<< "$STATEFULSETS"
      EOT
    }
  ]
}

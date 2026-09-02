locals {
  action_cronjobs = {
    preflight-checks-k8s = {
      cronjob     = "${local.safe_name}-preflight"
      description = "Run read-only source and target Redis checks without changing data."
      mode        = "preflight"
    }
    dump-restore-k8s = {
      cronjob     = "${local.safe_name}-driver"
      description = "Warm-copy all configured Redis datasets. Source is read-only; target reset requires allow_target_reset."
      mode        = "run"
    }
    reset-target-db-k8s = {
      cronjob     = "${local.safe_name}-driver"
      description = "FLUSHDB only configured target DB indexes, guarded by allow_target_reset."
      mode        = "reset-target"
    }
    verify-restore-k8s = {
      cronjob     = "${local.safe_name}-verify"
      description = "Compare Redis DB key counts and sampled key presence between source and target."
      mode        = "verify"
    }
    show-status-k8s = {
      cronjob     = "${local.safe_name}-poller"
      description = "Print module checkpoint state."
      mode        = "status"
    }
    debug-runner-k8s = {
      cronjob     = "${local.safe_name}-driver"
      description = "Create a short-lived debug pod with redis-cli and configured env."
      mode        = "debug-shell"
    }
  }
}

resource "facets_tekton_action_kubernetes" "redis_dump_restore" {
  for_each = local.action_cronjobs

  name                 = each.key
  description          = each.value.description
  facets_resource_name = var.instance_name
  facets_environment   = var.environment
  facets_resource = merge({
    kind    = "redis_dump_restore"
    flavor  = "dump_restore"
    version = "1.0"
  }, var.instance)
  params = []

  steps = [
    {
      name  = each.key
      image = "bitnamilegacy/kubectl:1.33.4"
      env = [
        {
          name  = "NAMESPACE"
          value = local.namespace
        },
        {
          name  = "CRONJOB"
          value = each.value.cronjob
        },
        {
          name  = "ACTION"
          value = each.key
        },
        {
          name  = "ACTION_MODE"
          value = each.value.mode
        }
      ]
      script = <<-EOT
        #!/bin/bash
        set -euo pipefail

        JOB="$CRONJOB-manual-$(date +%s)"
        echo "Creating job $JOB from cronjob/$CRONJOB in namespace $NAMESPACE"

        json_escape() {
          printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
        }
        mode_patch() {
          printf '[{"op":"replace","path":"/spec/template/spec/containers/0/args","value":["%s"]}]' "$(json_escape "$ACTION_MODE")"
        }
        debug_patch() {
          printf '[{"op":"replace","path":"/spec/template/spec/containers/0/command","value":["sh","-lc"]},{"op":"replace","path":"/spec/template/spec/containers/0/args","value":["echo debug pod ready; sleep 3600"]},{"op":"add","path":"/spec/template/spec/activeDeadlineSeconds","value":3660}]'
        }

        if [ "$ACTION_MODE" = "debug-shell" ]; then
          kubectl create job "$JOB" -n "$NAMESPACE" --from="cronjob/$CRONJOB" --dry-run=client -o yaml \
            | kubectl patch --local -f - --type=json -p "$(debug_patch)" -o yaml \
            | kubectl create -f -
        else
          kubectl create job "$JOB" -n "$NAMESPACE" --from="cronjob/$CRONJOB" --dry-run=client -o yaml \
            | kubectl patch --local -f - --type=json -p "$(mode_patch)" -o yaml \
            | kubectl create -f -
        fi

        echo "Waiting for pod scheduling"
        for _ in $(seq 1 120); do
          POD="$(kubectl get pods -n "$NAMESPACE" -l job-name="$JOB" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
          if [ -n "$POD" ]; then break; fi
          sleep 2
        done

        if [ -z "$POD" ]; then
          echo "No pod was created for $JOB"
          exit 1
        fi

        echo "Pod: $POD"
        kubectl wait -n "$NAMESPACE" --for=condition=Ready "pod/$POD" --timeout=300s || true
        if [ "$ACTION_MODE" = "debug-shell" ]; then
          echo "Debug pod is ready for exec:"
          echo "kubectl exec -n $NAMESPACE -it $POD -- sh"
          exit 0
        fi

        kubectl logs -n "$NAMESPACE" -f "$POD" || true
        if kubectl wait -n "$NAMESPACE" --for=condition=complete "job/$JOB" --timeout=10s; then
          echo "$ACTION completed"
          exit 0
        fi

        echo "$ACTION did not complete successfully"
        kubectl get job "$JOB" -n "$NAMESPACE" -o wide || true
        kubectl wait -n "$NAMESPACE" --for=condition=failed "job/$JOB" --timeout=1s || true
        exit 1
      EOT
    }
  ]
}

locals {
  action_cronjobs = {
    run = {
      cronjob     = "${local.safe_name}-driver"
      description = "Advance replication from the current checkpoint. Re-running this action is the resume path."
      mode        = "driver"
      params      = []
    }
    run-selected = {
      cronjob     = "${local.safe_name}-driver"
      description = "Advance replication for a comma-separated subset of databases."
      mode        = "driver"
      params = [
        {
          name = "dbs"
          type = "string"
        }
      ]
    }
    attach-existing = {
      cronjob     = "${local.safe_name}-driver"
      description = "Start attach-only logical replication against an existing parity-verified target without schema reset or initial table copy."
      mode        = "attach-existing"
      params = [
        {
          name = "confirm_existing_baseline"
          type = "string"
        },
        {
          name = "confirm_source_writes_frozen"
          type = "string"
        }
      ]
    }
    rebaseline-selected = {
      cronjob     = "${local.safe_name}-driver"
      description = "Rebuild replication for a comma-separated subset of databases after explicit cleanup."
      mode        = "driver"
      params = [
        {
          name = "dbs"
          type = "string"
        },
        {
          name = "rebaseline_id"
          type = "string"
        }
      ]
    }
    stop-selected = {
      cronjob     = "${local.safe_name}-driver"
      description = "Cleanly stop replication for a comma-separated subset without restarting phases."
      mode        = "stop-selected"
      params = [
        {
          name = "dbs"
          type = "string"
        }
      ]
    }
    stop-all = {
      cronjob     = "${local.safe_name}-driver"
      description = "Cleanly stop replication for all configured databases without restarting phases."
      mode        = "stop-all"
      params      = []
    }
    preflight = {
      cronjob     = "${local.safe_name}-preflight"
      description = "Run read-only source and target checks without advancing phases."
      mode        = "preflight-only"
      params      = []
    }
    discover-roles = {
      cronjob     = "${local.safe_name}-preflight"
      description = "Read-only discovery of source roles referenced by migrated database ownership and grants."
      mode        = "discover-roles"
      params      = []
    }
    match-grants = {
      cronjob     = "${local.safe_name}-driver"
      description = "Replay source object grants and compatible role memberships onto existing target roles."
      mode        = "match-grants"
      params      = []
    }
    match-grants-dryrun = {
      cronjob     = "${local.safe_name}-preflight"
      description = "Print source object grants and compatible role memberships that would be replayed on target, without applying them."
      mode        = "match-grants-dryrun"
      params      = []
    }
    verify-parity = {
      cronjob     = "${local.safe_name}-verify-parity"
      description = "Compare per-table row counts between source and target."
      mode        = "verify-parity"
      params      = []
    }
    verify-lag = {
      cronjob     = "${local.safe_name}-verify-lag"
      description = "Report replication slot retention and subscription lag."
      mode        = "verify-lag"
      params      = []
    }
    cutover = {
      cronjob     = "${local.safe_name}-driver"
      description = "Cutover hold: after replication is caught up, sync target sequences and disable the subscription without dropping it."
      mode        = "cutover-hold"
      params      = []
    }
    cutover-hold = {
      cronjob     = "${local.safe_name}-driver"
      description = "After replication is caught up, sync target sequences and disable the subscription without dropping it."
      mode        = "cutover-hold"
      params      = []
    }
    resume = {
      cronjob     = "${local.safe_name}-driver"
      description = "Resume a cutover-held subscription after confirming no target writes happened while held."
      mode        = "resume"
      params = [
        {
          name = "confirm_no_target_writes"
          type = "string"
        }
      ]
    }
    finalize-cutover = {
      cronjob     = "${local.safe_name}-driver"
      description = "Finalize a cutover-held database by dropping the target subscription and cleaning the source slot."
      mode        = "finalize-cutover"
      params      = []
    }
    status = {
      cronjob     = "${local.safe_name}-poller"
      description = "Print the checkpoint ConfigMap and refresh the Slack tracker when configured."
      mode        = "status"
      params      = []
    }
    debug-shell = {
      cronjob     = "${local.safe_name}-driver"
      description = "Create a short-lived debug pod with the same runner image, env, RBAC, and network path without running replication."
      mode        = "debug-shell"
      params      = []
    }
  }
}

resource "facets_tekton_action_kubernetes" "postgres_replication" {
  for_each = local.action_cronjobs

  name                 = each.key
  description          = each.value.description
  facets_resource_name = var.instance_name
  facets_environment   = var.environment
  facets_resource = merge({
    kind    = "postgres_replication"
    flavor  = "logical"
    version = "1.1"
  }, var.instance)
  params = each.value.params

  steps = [
    {
      name  = each.key
      image = "bitnamilegacy/kubectl:1.33.4"
      env = concat([
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
        ],
        contains(["run-selected", "rebaseline-selected", "stop-selected"], each.key) ? [{
          name  = "ACTION_DBS"
          value = "$(params.dbs)"
        }] : [],
        each.key == "rebaseline-selected" ? [{
          name  = "ACTION_REBASELINE_ID"
          value = "$(params.rebaseline_id)"
        }] : [],
        each.key == "resume" ? [{
          name  = "ACTION_RESUME_CONFIRM_NO_TARGET_WRITES"
          value = "$(params.confirm_no_target_writes)"
        }] : [],
        each.key == "attach-existing" ? [
          {
            name  = "ACTION_ATTACH_CONFIRM_EXISTING_BASELINE"
            value = "$(params.confirm_existing_baseline)"
          },
          {
            name  = "ACTION_ATTACH_CONFIRM_SOURCE_WRITES_FROZEN"
            value = "$(params.confirm_source_writes_frozen)"
          }
        ] : [],
        each.key == "debug-shell" ? [{
          name  = "DEBUG_TTL_SECONDS"
          value = "3600"
        }] : []
      )
      script = <<-EOT
        #!/bin/bash
        set -euo pipefail

        JOB="$CRONJOB-manual-$(date +%s)"
        echo "Creating job $JOB from cronjob/$CRONJOB in namespace $NAMESPACE"
        json_escape() {
          printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
        }
        env_json_patch() {
          patches="[{\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"ACTION_MODE_OVERRIDE\",\"value\":\"$(json_escape "$ACTION_MODE")\"}}"
          if [ -n "$${ACTION_DBS:-}" ]; then
            patches="$patches,{\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"SELECTED_DBS\",\"value\":\"$(json_escape "$ACTION_DBS")\"}}"
          fi
          if [ -n "$${ACTION_REBASELINE_ID:-}" ]; then
            patches="$patches,{\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"REBASELINE_ID\",\"value\":\"$(json_escape "$ACTION_REBASELINE_ID")\"}}"
          fi
          if [ -n "$${ACTION_RESUME_CONFIRM_NO_TARGET_WRITES:-}" ]; then
            patches="$patches,{\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"RESUME_CONFIRM_NO_TARGET_WRITES\",\"value\":\"$(json_escape "$ACTION_RESUME_CONFIRM_NO_TARGET_WRITES")\"}}"
          fi
          if [ -n "$${ACTION_ATTACH_CONFIRM_EXISTING_BASELINE:-}" ]; then
            patches="$patches,{\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"ATTACH_CONFIRM_EXISTING_BASELINE\",\"value\":\"$(json_escape "$ACTION_ATTACH_CONFIRM_EXISTING_BASELINE")\"}}"
          fi
          if [ -n "$${ACTION_ATTACH_CONFIRM_SOURCE_WRITES_FROZEN:-}" ]; then
            patches="$patches,{\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"ATTACH_CONFIRM_SOURCE_WRITES_FROZEN\",\"value\":\"$(json_escape "$ACTION_ATTACH_CONFIRM_SOURCE_WRITES_FROZEN")\"}}"
          fi
          printf '%s]' "$patches"
        }
        debug_json_patch() {
          ttl="$${DEBUG_TTL_SECONDS:-3600}"
          case "$ttl" in
            ''|*[!0-9]*)
              echo "DEBUG_TTL_SECONDS must be an integer number of seconds" >&2
              exit 1
              ;;
          esac
          if [ "$ttl" -lt 60 ] || [ "$ttl" -gt 7200 ]; then
            echo "DEBUG_TTL_SECONDS must be between 60 and 7200" >&2
            exit 1
          fi
          deadline=$((ttl + 60))
          printf '[{"op":"replace","path":"/spec/template/spec/containers/0/command","value":["sh","-lc"]},{"op":"replace","path":"/spec/template/spec/containers/0/args","value":["echo debug pod ready; sleep %s"]},{"op":"add","path":"/spec/template/spec/activeDeadlineSeconds","value":%s}]' "$ttl" "$deadline"
        }

        if [ -n "$${ACTION_DBS:-}" ]; then
          echo "Selected databases: $ACTION_DBS"
        elif [ "$ACTION" = "debug-shell" ]; then
          echo "Creating debug shell pod for $${DEBUG_TTL_SECONDS:-3600}s"
        else
          echo "Running mode: $ACTION_MODE"
        fi
        if [ "$ACTION" = "debug-shell" ]; then
          kubectl create job "$JOB" -n "$NAMESPACE" --from="cronjob/$CRONJOB" --dry-run=client -o yaml \
            | kubectl patch --local -f - --type=json -p "$(debug_json_patch)" -o yaml \
            | kubectl create -f -
        else
          kubectl create job "$JOB" -n "$NAMESPACE" --from="cronjob/$CRONJOB" --dry-run=client -o yaml \
            | kubectl patch --local -f - --type=json -p "$(env_json_patch)" -o yaml \
            | kubectl create -f -
        fi

        echo "Waiting for pod scheduling"
        for _ in $(seq 1 120); do
          POD="$(kubectl get pods -n "$NAMESPACE" -l job-name="$JOB" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
          if [ -n "$POD" ]; then
            break
          fi
          sleep 2
        done

        if [ -z "$POD" ]; then
          echo "No pod was created for $JOB"
          kubectl describe job "$JOB" -n "$NAMESPACE" || true
          exit 1
        fi

        echo "Pod: $POD"
        kubectl wait -n "$NAMESPACE" --for=condition=Ready "pod/$POD" --timeout=300s || true
        if [ "$ACTION" = "debug-shell" ]; then
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

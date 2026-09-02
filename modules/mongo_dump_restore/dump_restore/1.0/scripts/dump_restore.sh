#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="${MONGO_DUMP_RESTORE_SCRIPT_DIR:-/scripts}"
source "$SCRIPT_DIR/config.sh"

mode="${ACTION_MODE_OVERRIDE:-${1:-status}}"

need_tools() {
  local missing=0
  for tool in jq curl mongosh mongodump mongorestore; do
    command -v "$tool" >/dev/null 2>&1 || missing=1
  done
  [ "$missing" -eq 0 ] && return 0
  if command -v apk >/dev/null 2>&1; then
    apk add --no-cache jq curl >/dev/null
  elif command -v apt-get >/dev/null 2>&1; then
    # Official Mongo images can carry expired Mongo apt keys. The database
    # tools are already installed there, so disable that repo before installing
    # only generic runtime helpers from the base OS repositories.
    if [ -d /etc/apt/sources.list.d ]; then
      find /etc/apt/sources.list.d -maxdepth 1 -type f -name 'mongodb*.list' -exec mv {} {}.disabled \; 2>/dev/null || true
    fi
    apt-get update >/dev/null && apt-get install -y jq curl >/dev/null
  fi
  for tool in jq curl mongosh mongodump mongorestore; do
    command -v "$tool" >/dev/null 2>&1 || return 1
  done
}

urlencode() {
  jq -nr --arg v "$1" '$v|@uri'
}

append_option() {
  local current="$1" key="$2" value="$3"
  [ -n "$value" ] || {
    printf '%s' "$current"
    return 0
  }
  if [ -n "$current" ]; then
    printf '%s&%s=%s' "$current" "$key" "$value"
  else
    printf '%s=%s' "$key" "$value"
  fi
}

mongo_uri() {
  local side="$1" db="$2" host port user password auth_db tls invalid replica_set extra options
  if [ "$side" = "source" ]; then
    host="$SOURCE_HOST"; port="$SOURCE_PORT"; user="$SOURCE_ADMIN_USER"; password="$SOURCE_ADMIN_PASSWORD"
    auth_db="$SOURCE_AUTH_DATABASE"; tls="$SOURCE_TLS"; invalid="$SOURCE_TLS_ALLOW_INVALID_CERTIFICATES"
    replica_set="${SOURCE_REPLICA_SET:-}"; extra="${SOURCE_EXTRA_URI_OPTIONS:-}"
  else
    host="$TARGET_HOST"; port="$TARGET_PORT"; user="$TARGET_ADMIN_USER"; password="$TARGET_ADMIN_PASSWORD"
    auth_db="$TARGET_AUTH_DATABASE"; tls="$TARGET_TLS"; invalid="$TARGET_TLS_ALLOW_INVALID_CERTIFICATES"
    replica_set="${TARGET_REPLICA_SET:-}"; extra="${TARGET_EXTRA_URI_OPTIONS:-}"
  fi
  if [ -z "$password" ]; then
    echo "REFUSED: $side password is empty" >&2
    return 1
  fi
  options=""
  options="$(append_option "$options" authSource "$(urlencode "$auth_db")")"
  [ "$tls" = "true" ] && options="$(append_option "$options" tls true)"
  [ "$invalid" = "true" ] && options="$(append_option "$options" tlsInsecure true)"
  [ -n "$replica_set" ] && options="$(append_option "$options" replicaSet "$(urlencode "$replica_set")")"
  if [ -n "$extra" ]; then
    [ -n "$options" ] && options="$options&$extra" || options="$extra"
  fi
  printf 'mongodb://%s:%s@%s:%s/%s?%s' "$(urlencode "$user")" "$(urlencode "$password")" "$host" "$port" "$db" "$options"
}

kube_api_url() {
  [ -n "${KUBERNETES_SERVICE_HOST:-}" ] || return 1
  printf 'https://%s:%s' "$KUBERNETES_SERVICE_HOST" "${KUBERNETES_SERVICE_PORT_HTTPS:-443}"
}

state_path() {
  printf '/api/v1/namespaces/%s/configmaps/%s' "$NAMESPACE" "$STATE_CONFIGMAP"
}

kube_api_curl() {
  local method="$1" path="$2" payload="${3:-}" token ca content_type base
  token="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null || true)"
  ca=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  base="$(kube_api_url)" || return 1
  content_type="application/merge-patch+json"
  [ "$method" = "POST" ] && content_type="application/json"
  [ -n "$token" ] || return 1
  if [ -n "$payload" ]; then
    curl -fsS -X "$method" --cacert "$ca" -H "Authorization: Bearer $token" -H "Content-Type: $content_type" --data "$payload" "$base$path"
  else
    curl -fsS -X "$method" --cacert "$ca" -H "Authorization: Bearer $token" "$base$path"
  fi
}

ensure_state() {
  need_tools || return 1
  if kube_api_curl GET "$(state_path)" >/dev/null 2>&1; then
    return 0
  fi
  local body
  body="$(jq -n --arg name "$STATE_CONFIGMAP" --arg namespace "$NAMESPACE" '{
    apiVersion:"v1",
    kind:"ConfigMap",
    metadata:{name:$name, namespace:$namespace, labels:{"app.kubernetes.io/name":"mongo-dump-restore"}},
    data:{}
  }')"
  kube_api_curl POST "/api/v1/namespaces/$NAMESPACE/configmaps" "$body" >/dev/null
}

state_get() {
  local key="$1"
  ensure_state || return 0
  kube_api_curl GET "$(state_path)" 2>/dev/null | jq -r --arg key "$key" '.data[$key] // ""' 2>/dev/null || true
}

state_set() {
  local key="$1" value="$2" patch_payload
  ensure_state || {
    echo "state skipped: kubernetes API tools/env not available" >&2
    return 0
  }
  patch_payload="$(jq -n --arg key "$key" --arg value "$value" '{data:{($key):$value}}')"
  kube_api_curl PATCH "$(state_path)" "$patch_payload" >/dev/null
}

json_escape() {
  jq -Rs .
}

write_db_state() {
  local db_key="$1" phase="$2" last="$3" err="${4:-}" now body
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  body="$(jq -cn --arg phase "$phase" --arg last "$last" --arg updated_at "$now" --arg err "$err" \
    '{phase:$phase,last_completed_phase:$last,updated_at:$updated_at,last_error:$err}')"
  state_set "db-$db_key" "$body"
}

slack_api() {
  local method="$1" payload="$2"
  [ -n "${SLACK_CHANNEL_ID:-}" ] || return 0
  [ -n "${SLACK_TOKEN:-}" ] || return 0
  need_tools || return 0
  curl -fsS -X POST "https://slack.com/api/$method" \
    -H "Authorization: Bearer $SLACK_TOKEN" \
    -H "Content-type: application/json; charset=utf-8" \
    --data "$payload" >/tmp/slack-response.json || {
      echo "slack $method request failed" >&2
      return 0
    }
  if [ "$(jq -r '.ok // false' /tmp/slack-response.json)" != "true" ]; then
    echo "slack $method not ok: $(jq -r '.error // "unknown_error"' /tmp/slack-response.json)" >&2
  fi
}

slack_update() {
  [ -n "${SLACK_CHANNEL_ID:-}" ] || return 0
  [ -n "${SLACK_TOKEN:-}" ] || return 0
  need_tools || return 0
  local now text ts payload response_ts
  now="$(TZ=Asia/Kolkata date '+%d %b %Y, %H:%M IST')"
  text=":arrows_counterclockwise: ${STATE_CONFIGMAP} - Mongo dump restore
\`\`\`
$(status_summary)
\`\`\`
_Last updated: ${now}_"
  ts="$(state_get slack_message_ts)"
  if [ -n "$ts" ]; then
    payload="$(jq -n --arg channel "$SLACK_CHANNEL_ID" --arg ts "$ts" --arg text "$text" '{channel:$channel,ts:$ts,text:$text}')"
    slack_api chat.update "$payload"
  else
    payload="$(jq -n --arg channel "$SLACK_CHANNEL_ID" --arg text "$text" '{channel:$channel,text:$text}')"
    slack_api chat.postMessage "$payload"
    response_ts="$(jq -r '.ts // ""' /tmp/slack-response.json 2>/dev/null || true)"
    [ -n "$response_ts" ] && state_set slack_message_ts "$response_ts" || true
  fi
}

source_eval() {
  local db="$1" js="$2"
  mongosh "$(mongo_uri source "$db")" --quiet --eval "$js"
}

target_eval() {
  local db="$1" js="$2"
  mongosh "$(mongo_uri target "$db")" --quiet --eval "$js"
}

collection_count() {
  local side="$1" db="$2"
  if [ "$side" = "source" ]; then
    source_eval "$db" 'db.getCollectionNames().filter(c => !c.startsWith("system.")).length'
  else
    target_eval "$db" 'db.getCollectionNames().filter(c => !c.startsWith("system.")).length'
  fi
}

document_count() {
  local side="$1" db="$2"
  if [ "$side" = "source" ]; then
    source_eval "$db" 'db.getCollectionNames().filter(c => !c.startsWith("system.")).reduce((n,c) => n + db.getCollection(c).countDocuments({}), 0)'
  else
    target_eval "$db" 'db.getCollectionNames().filter(c => !c.startsWith("system.")).reduce((n,c) => n + db.getCollection(c).countDocuments({}), 0)'
  fi
}

dump_args_for_db() {
  local source_db="$1" excludes_csv="$2"
  local args=(mongodump --uri "$(mongo_uri source "$source_db")" --archive --numParallelCollections "$NUM_PARALLEL_COLLECTIONS")
  [ "$GZIP" = "true" ] && args+=(--gzip)
  if [ -n "$excludes_csv" ] && [ "$excludes_csv" != "null" ] && [ "$excludes_csv" != "__none__" ]; then
    IFS=',' read -ra excludes <<< "$excludes_csv"
    local collection
    for collection in "${excludes[@]}"; do
      [ -z "$collection" ] && continue
      [ "$collection" = "null" ] && continue
      [ "$collection" = "__none__" ] && continue
      args+=(--excludeCollection "$collection")
    done
  fi
  printf '%q ' "${args[@]}"
}

restore_args_for_db() {
  local source_db="$1" target_db="$2" preserve_uuids="$3"
  local args=(mongorestore --uri "$(mongo_uri target "$target_db")" --archive --noOptionsRestore --nsInclude "$source_db.*" --nsFrom "$source_db.*" --nsTo "$target_db.*")
  [ "$GZIP" = "true" ] && args+=(--gzip)
  [ "$preserve_uuids" = "true" ] && args+=(--preserveUUID)
  printf '%q ' "${args[@]}"
}

assert_known_target_db() {
  local target_db="$1" line key source_db configured_target rest
  while IFS=$'\t' read -r key source_db configured_target rest; do
    [ -z "${key:-}" ] && continue
    [ "$target_db" = "$configured_target" ] && return 0
  done <<< "$DATABASES_TSV"
  echo "REFUSED: target database $target_db is not configured for this resource" >&2
  return 1
}

preflight_db() {
  local key="$1" source_db="$2" target_db="$3" excludes_csv="$4"
  echo "== PREFLIGHT $key =="
  write_db_state "$key" "PREFLIGHT" "" ""
  echo "-- connectivity"
  local source_version target_version
  if ! source_version="$(source_eval "$source_db" 'db.version()')"; then
    echo "REFUSED: source connectivity/auth check failed" >&2
    return 1
  fi
  if ! target_version="$(target_eval "$target_db" 'db.version()')"; then
    echo "REFUSED: target connectivity/auth check failed" >&2
    return 1
  fi
  echo "source_version=$source_version"
  echo "target_version=$target_version"
  echo "-- database inventory"
  local source_collections target_collections source_docs
  if ! source_collections="$(collection_count source "$source_db")"; then
    echo "REFUSED: source collection inventory failed" >&2
    return 1
  fi
  if ! target_collections="$(collection_count target "$target_db")"; then
    echo "REFUSED: target collection inventory failed" >&2
    return 1
  fi
  if ! source_docs="$(document_count source "$source_db")"; then
    echo "REFUSED: source document inventory failed" >&2
    return 1
  fi
  echo "source_collections=$source_collections"
  echo "source_documents=$source_docs"
  echo "target_collections=$target_collections"
  if [ "$target_collections" -gt 0 ] && [ "$REQUIRE_EMPTY_TARGET" = "true" ] && [ "$ALLOW_TARGET_RESET" != "true" ]; then
    echo "REFUSED: target is not empty and target reset is not allowed" >&2
    return 1
  fi
  write_db_state "$key" "READY" "PREFLIGHT" ""
}

reset_target_db() {
  local key="$1" target_db="$2"
  assert_known_target_db "$target_db"
  if [ "$ALLOW_TARGET_RESET" != "true" ]; then
    echo "REFUSED: reset-target requires allow_target_reset=true" >&2
    return 1
  fi
  echo "== RESET_TARGET $key =="
  write_db_state "$key" "RESET_TARGET" "PREFLIGHT" ""
  target_eval "$target_db" 'db.dropDatabase()' >/dev/null || {
    echo "REFUSED: target reset failed" >&2
    return 1
  }
  write_db_state "$key" "READY" "RESET_TARGET" ""
}

restore_db() {
  local key="$1" source_db="$2" target_db="$3" excludes_csv="$4" preserve_uuids="$5"
  echo "== RUN $key =="
  write_db_state "$key" "DUMP_RESTORE" "PREFLIGHT" ""
  local target_collections dump_cmd restore_cmd
  target_collections="$(collection_count target "$target_db")"
  if [ "$target_collections" -gt 0 ]; then
    if [ "$ALLOW_TARGET_RESET" = "true" ]; then
      reset_target_db "$key" "$target_db"
    else
      echo "-- target has $target_collections collections; verifying existing restore instead of resetting"
      write_db_state "$key" "VERIFY" "PREFLIGHT" ""
      verify_db "$key" "$source_db" "$target_db" "$excludes_csv"
      write_db_state "$key" "COMPLETED" "VERIFY" ""
      return 0
    fi
  fi
  echo "-- dump source and restore target"
  dump_cmd="$(dump_args_for_db "$source_db" "$excludes_csv")"
  restore_cmd="$(restore_args_for_db "$source_db" "$target_db" "$preserve_uuids")"
  echo "dump_command=mongodump <redacted> $source_db"
  echo "restore_command=mongorestore <redacted> $target_db"
  # shellcheck disable=SC2086
  if ! eval "$dump_cmd" | eval "$restore_cmd"; then
    echo "REFUSED: dump restore pipeline failed" >&2
    return 1
  fi
  write_db_state "$key" "VERIFY" "DUMP_RESTORE" ""
  verify_db "$key" "$source_db" "$target_db" "$excludes_csv"
  write_db_state "$key" "COMPLETED" "VERIFY" ""
}

verify_db() {
  local key="$1" source_db="$2" target_db="$3" excludes_csv="$4"
  echo "== VERIFY $key =="
  local source_collections target_collections source_docs target_docs excluded_count
  source_collections="$(collection_count source "$source_db")"
  target_collections="$(collection_count target "$target_db")"
  source_docs="$(document_count source "$source_db")"
  target_docs="$(document_count target "$target_db")"
  excluded_count=0
  if [ -n "$excludes_csv" ] && [ "$excludes_csv" != "null" ] && [ "$excludes_csv" != "__none__" ]; then
    IFS=',' read -ra excludes <<< "$excludes_csv"
    excluded_count="${#excludes[@]}"
  fi
  echo "source_collections=$source_collections"
  echo "target_collections=$target_collections"
  echo "excluded_collections=$excluded_count"
  echo "source_documents=$source_docs"
  echo "target_documents=$target_docs"
  if [ "$target_collections" -ne $((source_collections - excluded_count)) ]; then
    echo "REFUSED: collection count mismatch" >&2
    return 1
  fi
  if [ "$excluded_count" -eq 0 ] && [ "$source_docs" -ne "$target_docs" ]; then
    echo "REFUSED: document count mismatch" >&2
    return 1
  fi
}

for_each_db() {
  local fn="$1" failed=0
  local key source_db target_db excludes preserve_uuids
  while IFS=$'\t' read -r key source_db target_db excludes preserve_uuids; do
    [ -z "${key:-}" ] && continue
    "$fn" "$key" "$source_db" "$target_db" "${excludes:-}" "${preserve_uuids:-false}" || {
      write_db_state "$key" "ERROR" "$(state_get "db-$key" | jq -r '.last_completed_phase // ""' 2>/dev/null || true)" "failed in $fn"
      failed=1
    }
  done <<< "$DATABASES_TSV"
  return "$failed"
}

status_dump() {
  ensure_state || {
    echo "{}"
    return 0
  }
  kube_api_curl GET "$(state_path)" 2>/dev/null || echo "{}"
}

status_summary() {
  local key source_db target_db rest state
  while IFS=$'\t' read -r key source_db target_db rest; do
    [ -z "${key:-}" ] && continue
    state="$(state_get "db-$key")"
    if [ -z "$state" ]; then
      printf '%s: phase=NEW last= collections=unknown error=\n' "$key"
    else
      printf '%s\n' "$state" | jq -r --arg key "$key" '"\($key): phase=\(.phase) last=\(.last_completed_phase) updated_at=\(.updated_at) error=\(.last_error)"'
    fi
  done <<< "$DATABASES_TSV"
}

main() {
  local rc=0
  if ! need_tools; then
    echo "REFUSED: required tools are missing: jq curl mongosh mongodump mongorestore" >&2
    return 1
  fi
  case "$mode" in
    preflight)
      for_each_db preflight_db || rc=$?
      ;;
    run)
      for_each_db restore_db || rc=$?
      ;;
    reset-target)
      for_each_db reset_target_db || rc=$?
      ;;
    verify)
      for_each_db verify_db || rc=$?
      ;;
    status|poll)
      status_dump
      ;;
    *)
      echo "unknown mode $mode" >&2
      exit 2
      ;;
  esac
  slack_update || true
  return "$rc"
}

if [ "${MONGO_DUMP_RESTORE_LIB_ONLY:-false}" != "true" ]; then
  main "$@"
fi

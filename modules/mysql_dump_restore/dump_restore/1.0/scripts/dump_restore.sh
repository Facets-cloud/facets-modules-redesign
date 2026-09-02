#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="${MYSQL_DUMP_RESTORE_SCRIPT_DIR:-/scripts}"
source "$SCRIPT_DIR/config.sh"

mode="${ACTION_MODE_OVERRIDE:-${1:-status}}"

need_tools() {
  if command -v jq >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
    return 0
  fi
  if command -v apk >/dev/null 2>&1; then
    apk add --no-cache jq curl >/dev/null
  elif command -v microdnf >/dev/null 2>&1; then
    microdnf install -y jq curl >/dev/null
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y jq curl >/dev/null
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update >/dev/null && apt-get install -y jq curl >/dev/null
  else
    return 1
  fi
}

mysql_source_base=(
  mysql
  --protocol=TCP
  --host="$SOURCE_HOST"
  --port="$SOURCE_PORT"
  --user="$SOURCE_ADMIN_USER"
  --password="$SOURCE_ADMIN_PASSWORD"
  --default-character-set="$DEFAULT_CHARACTER_SET"
  --batch
  --raw
  --skip-column-names
)

mysql_target_base=(
  mysql
  --protocol=TCP
  --host="$TARGET_HOST"
  --port="$TARGET_PORT"
  --user="$TARGET_ADMIN_USER"
  --password="$TARGET_ADMIN_PASSWORD"
  --default-character-set="$DEFAULT_CHARACTER_SET"
  --batch
  --raw
  --skip-column-names
)

mysql_dump_base=(
  mysqldump
  --protocol=TCP
  --host="$SOURCE_HOST"
  --port="$SOURCE_PORT"
  --user="$SOURCE_ADMIN_USER"
  --password="$SOURCE_ADMIN_PASSWORD"
  --default-character-set="$DEFAULT_CHARACTER_SET"
  --single-transaction
  --quick
  --skip-lock-tables
  --hex-blob
  --no-tablespaces
  --set-gtid-purged=OFF
  --column-statistics=0
)

kube_api_url() {
  if [ -z "${KUBERNETES_SERVICE_HOST:-}" ]; then
    return 1
  fi
  printf 'https://%s:%s' "$KUBERNETES_SERVICE_HOST" "${KUBERNETES_SERVICE_PORT_HTTPS:-443}"
}

state_path() {
  printf '/api/v1/namespaces/%s/configmaps/%s' "$NAMESPACE" "$STATE_CONFIGMAP"
}

kube_api_token() {
  cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null
}

kube_api_curl() {
  local method="$1" path="$2" payload="${3:-}" token ca content_type base
  token="$(kube_api_token)"
  ca=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  base="$(kube_api_url)" || return 1
  content_type="application/merge-patch+json"
  [ "$method" = "POST" ] && content_type="application/json"
  [ "$method" = "PUT" ] && content_type="application/json"
  [ -n "$token" ] || return 1
  if [ -n "$payload" ]; then
    curl -fsS -X "$method" --cacert "$ca" \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: $content_type" \
      --data "$payload" "$base$path"
  else
    curl -fsS -X "$method" --cacert "$ca" \
      -H "Authorization: Bearer $token" \
      "$base$path"
  fi
}

ensure_state() {
  if command -v kubectl >/dev/null 2>&1; then
    kubectl get cm "$STATE_CONFIGMAP" -n "$NAMESPACE" >/dev/null 2>&1 \
      || kubectl create cm "$STATE_CONFIGMAP" -n "$NAMESPACE" >/dev/null
    return 0
  fi
  need_tools || return 1
  if kube_api_curl GET "$(state_path)" >/dev/null 2>&1; then
    return 0
  fi
  local body
  body="$(jq -n --arg name "$STATE_CONFIGMAP" --arg namespace "$NAMESPACE" '{
    apiVersion:"v1",
    kind:"ConfigMap",
    metadata:{name:$name, namespace:$namespace, labels:{"app.kubernetes.io/name":"mysql-dump-restore"}},
    data:{}
  }')"
  kube_api_curl POST "/api/v1/namespaces/$NAMESPACE/configmaps" "$body" >/dev/null
}

state_get() {
  local key="$1"
  if command -v kubectl >/dev/null 2>&1; then
    ensure_state || return 0
    kubectl get cm "$STATE_CONFIGMAP" -n "$NAMESPACE" -o json | jq -r --arg key "$key" '.data[$key] // ""' 2>/dev/null || true
    return 0
  fi
  ensure_state || return 0
  kube_api_curl GET "$(state_path)" 2>/dev/null | jq -r --arg key "$key" '.data[$key] // ""' 2>/dev/null || true
}

state_set() {
  local key="$1" value="$2" patch_payload
  if command -v kubectl >/dev/null 2>&1; then
    ensure_state || return 0
    kubectl patch cm "$STATE_CONFIGMAP" -n "$NAMESPACE" --type=merge -p "$(jq -n --arg key "$key" --arg value "$value" '{data:{($key):$value}}')" >/dev/null
    return 0
  fi
  ensure_state || {
    echo "state skipped: kubernetes API tools/env not available" >&2
    return 0
  }
  patch_payload="$(jq -n --arg key "$key" --arg value "$value" '{data:{($key):$value}}')"
  kube_api_curl PATCH "$(state_path)" "$patch_payload" >/dev/null
}

slack_api() {
  local method="$1" payload="$2"
  if [ -z "${SLACK_CHANNEL_ID:-}" ] || [ -z "${SLACK_TOKEN:-}" ]; then
    return 0
  fi
  if ! need_tools; then
    echo "slack skipped: jq/curl not found in runner image" >&2
    return 0
  fi
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
  if [ -z "${SLACK_CHANNEL_ID:-}" ] || [ -z "${SLACK_TOKEN:-}" ]; then
    return 0
  fi
  if ! need_tools; then
    echo "slack skipped: jq/curl not found in runner image" >&2
    return 0
  fi
  local now text ts payload response_ts
  now="$(TZ=Asia/Kolkata date '+%d %b %Y, %H:%M IST')"
  text=":arrows_counterclockwise: ${STATE_CONFIGMAP} - MySQL dump restore
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

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//'
}

write_db_state() {
  local db_key="$1" phase="$2" last="$3" err="${4:-}"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  state_set "db-$db_key-phase" "$phase"
  state_set "db-$db_key-last_completed_phase" "$last"
  state_set "db-$db_key-updated_at" "$now"
  state_set "db-$db_key-last_error" "$err"
  state_set "db-$db_key" "{\"phase\":\"$(json_escape "$phase")\",\"last_completed_phase\":\"$(json_escape "$last")\",\"updated_at\":\"$now\",\"last_error\":\"$(json_escape "$err")\"}"
}

sql_ident() {
  local ident="$1"
  case "$ident" in
    ""|*[\`]*)
      echo "invalid identifier: $ident" >&2
      return 1
      ;;
  esac
  printf '`%s`' "$ident"
}

assert_known_target_db() {
  local target_db="$1" line key source_db configured_target rest
  while IFS=$'\t' read -r key source_db configured_target rest; do
    [ -z "${key:-}" ] && continue
    if [ "$target_db" = "$configured_target" ]; then
      return 0
    fi
  done <<< "$DATABASES_TSV"
  echo "REFUSED: target database $target_db is not configured for this resource" >&2
  return 1
}

source_sql() {
  "${mysql_source_base[@]}" --execute="$1"
}

target_sql() {
  "${mysql_target_base[@]}" --execute="$1"
}

capture_source_sql() {
  local __var="$1" query="$2" output
  if ! output="$(source_sql "$query")"; then
    echo "REFUSED: source query failed" >&2
    return 1
  fi
  printf -v "$__var" '%s' "$output"
}

capture_target_sql() {
  local __var="$1" query="$2" output
  if ! output="$(target_sql "$query")"; then
    echo "REFUSED: target query failed" >&2
    return 1
  fi
  printf -v "$__var" '%s' "$output"
}

session_prefix() {
  local lock_ms
  lock_ms=$((LOCK_TIMEOUT_SECONDS * 1000))
  if [ "$FORCE_UTC" = "true" ]; then
    printf "SET SESSION time_zone = '+00:00'; SET SESSION lock_wait_timeout = %s; " "$LOCK_TIMEOUT_SECONDS"
  else
    printf "SET SESSION lock_wait_timeout = %s; " "$LOCK_TIMEOUT_SECONDS"
  fi
}

dump_args_for_db() {
  local source_db="$1" excludes_csv="$2" include_routines="$3" include_triggers="$4" include_events="$5"
  local args=("${mysql_dump_base[@]}")
  [ "$include_routines" = "true" ] && args+=(--routines) || args+=(--skip-routines)
  [ "$include_triggers" = "true" ] && args+=(--triggers) || args+=(--skip-triggers)
  [ "$include_events" = "true" ] && args+=(--events) || args+=(--skip-events)
  if [ -n "$excludes_csv" ] && [ "$excludes_csv" != "null" ] && [ "$excludes_csv" != "__none__" ]; then
    IFS=',' read -ra excludes <<< "$excludes_csv"
    local table
    for table in "${excludes[@]}"; do
      [ -z "$table" ] && continue
      [ "$table" = "null" ] && continue
      [ "$table" = "__none__" ] && continue
      args+=("--ignore-table=$table")
    done
  fi
  args+=("$source_db")
  printf '%q ' "${args[@]}"
}

strip_definers_filter() {
  if [ "$STRIP_DEFINERS" = "true" ]; then
    sed -E 's/DEFINER=`[^`]+`@`[^`]+`//g; s/DEFINER=[^ ]+//g'
  else
    cat
  fi
}

preflight_db() {
  local key="$1" source_db="$2" target_db="$3" excludes_csv="$4"
  echo "== PREFLIGHT $key =="
  write_db_state "$key" "PREFLIGHT" "" ""

  echo "-- connectivity"
  local source_version target_version
  capture_source_sql source_version "SELECT VERSION();" || return 1
  capture_target_sql target_version "SELECT VERSION();" || return 1
  echo "source_version=$source_version"
  echo "target_version=$target_version"

  echo "-- charset/collation/timezone"
  local source_charset target_charset source_collation target_collation source_tz target_tz
  capture_source_sql source_charset "SELECT DEFAULT_CHARACTER_SET_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$source_db';" || return 1
  capture_target_sql target_charset "SELECT DEFAULT_CHARACTER_SET_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$target_db';" || return 1
  capture_source_sql source_collation "SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$source_db';" || return 1
  capture_target_sql target_collation "SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$target_db';" || return 1
  capture_source_sql source_tz "SELECT @@global.time_zone, @@session.time_zone, @@system_time_zone;" || return 1
  capture_target_sql target_tz "SELECT @@global.time_zone, @@session.time_zone, @@system_time_zone;" || return 1
  echo "source_charset=$source_charset"
  echo "target_charset=${target_charset:-missing}"
  echo "source_collation=$source_collation"
  echo "target_collation=${target_collation:-missing}"
  echo "source_time_zone=$source_tz"
  echo "target_time_zone=$target_tz"
  if [ -n "$target_charset" ] && [ "$source_charset" != "$target_charset" ] && [ "$ALLOW_CHARSET_MISMATCH" != "true" ]; then
    echo "REFUSED: charset differs; set allow_charset_mismatch=true to accept" >&2
    return 1
  fi
  if [ -n "$target_collation" ] && [ "$source_collation" != "$target_collation" ] && [ "$ALLOW_COLLATION_MISMATCH" != "true" ]; then
    echo "REFUSED: collation differs; set allow_collation_mismatch=true to accept" >&2
    return 1
  fi

  echo "-- max_allowed_packet"
  local source_packet target_packet
  capture_source_sql source_packet "SELECT @@max_allowed_packet;" || return 1
  capture_target_sql target_packet "SELECT @@max_allowed_packet;" || return 1
  echo "source_max_allowed_packet=$source_packet"
  echo "target_max_allowed_packet=$target_packet"
  if [ "$target_packet" -lt "$MIN_MAX_ALLOWED_PACKET_BYTES" ]; then
    echo "REFUSED: target max_allowed_packet below $MIN_MAX_ALLOWED_PACKET_BYTES" >&2
    return 1
  fi
  if [ "$target_packet" -lt "$source_packet" ]; then
    echo "REFUSED: target max_allowed_packet below source" >&2
    return 1
  fi

  echo "-- engines"
  local non_innodb
  capture_source_sql non_innodb "SELECT CONCAT(TABLE_SCHEMA,'.',TABLE_NAME,':',ENGINE) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$source_db' AND TABLE_TYPE='BASE TABLE' AND ENGINE <> 'InnoDB' ORDER BY 1;" || return 1
  non_innodb="$(printf '%s\n' "$non_innodb" | paste -sd ',' -)"
  echo "non_innodb=${non_innodb:-0}"
  if [ -n "$non_innodb" ] && [ "$ALLOW_NON_INNODB" != "true" ]; then
    echo "REFUSED: non-InnoDB tables are not consistent with --single-transaction" >&2
    return 1
  fi

  echo "-- decimal/generated/blob metadata"
  local column_metadata
  capture_source_sql column_metadata "SELECT CONCAT(TABLE_SCHEMA,'.',TABLE_NAME,'.',COLUMN_NAME,':',COLUMN_TYPE) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$source_db' AND (DATA_TYPE IN ('decimal','numeric') OR EXTRA LIKE '%GENERATED%' OR DATA_TYPE IN ('blob','mediumblob','longblob','tinyblob')) ORDER BY 1;" || return 1
  printf '%s\n' "$column_metadata" | sed '/^$/d; s/^/column=/'

  echo "-- target emptiness"
  local target_tables
  capture_target_sql target_tables "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$target_db' AND TABLE_TYPE='BASE TABLE';" || return 1
  echo "target_regular_tables=$target_tables"
  if [ "$target_tables" -gt 0 ] && [ "$REQUIRE_EMPTY_TARGET" = "true" ] && [ "$ALLOW_TARGET_RESET" != "true" ]; then
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
  local quoted
  quoted="$(sql_ident "$target_db")"
  target_sql "$(session_prefix) DROP DATABASE IF EXISTS $quoted; CREATE DATABASE $quoted CHARACTER SET $DEFAULT_CHARACTER_SET;" || {
    echo "REFUSED: target reset failed" >&2
    return 1
  }
  write_db_state "$key" "READY" "RESET_TARGET" ""
}

restore_db() {
  local key="$1" source_db="$2" target_db="$3" excludes_csv="$4" include_routines="$5" include_triggers="$6" include_events="$7"
  echo "== RUN $key =="
  write_db_state "$key" "DUMP_RESTORE" "PREFLIGHT" ""

  local target_tables quoted
  capture_target_sql target_tables "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$target_db' AND TABLE_TYPE='BASE TABLE';" || return 1
  if [ "$target_tables" -gt 0 ]; then
    if [ "$ALLOW_TARGET_RESET" = "true" ]; then
      reset_target_db "$key" "$target_db"
    else
      echo "REFUSED: target has $target_tables tables; set allow_target_reset=true or run against an empty target" >&2
      return 1
    fi
  else
    quoted="$(sql_ident "$target_db")"
    target_sql "$(session_prefix) CREATE DATABASE IF NOT EXISTS $quoted CHARACTER SET $DEFAULT_CHARACTER_SET;" || {
      echo "REFUSED: target database create failed" >&2
      return 1
    }
  fi

  echo "-- dump source and restore target"
  local dump_cmd
  dump_cmd="$(dump_args_for_db "$source_db" "$excludes_csv" "$include_routines" "$include_triggers" "$include_events")"
  echo "dump_command=mysqldump <redacted> $source_db"
  # shellcheck disable=SC2086
  if ! eval "$dump_cmd" \
    | strip_definers_filter \
    | "${mysql_target_base[@]}" "$target_db"; then
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
  local source_tables target_tables
  capture_source_sql source_tables "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$source_db' AND TABLE_TYPE='BASE TABLE';" || return 1
  capture_target_sql target_tables "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$target_db' AND TABLE_TYPE='BASE TABLE';" || return 1
  local excluded_count=0
  if [ -n "$excludes_csv" ] && [ "$excludes_csv" != "null" ] && [ "$excludes_csv" != "__none__" ]; then
    IFS=',' read -ra excludes <<< "$excludes_csv"
    excluded_count="${#excludes[@]}"
  fi
  echo "source_regular_tables=$source_tables"
  echo "target_regular_tables=$target_tables"
  echo "excluded_tables=$excluded_count"
  if [ "$target_tables" -ne $((source_tables - excluded_count)) ]; then
    echo "REFUSED: table count mismatch" >&2
    return 1
  fi
}

for_each_db() {
  local fn="$1" failed=0
  local key source_db target_db excludes include_routines include_triggers include_events
  while IFS=$'\t' read -r key source_db target_db excludes include_routines include_triggers include_events; do
    [ -z "${key:-}" ] && continue
    "$fn" "$key" "$source_db" "$target_db" "${excludes:-}" "${include_routines:-true}" "${include_triggers:-true}" "${include_events:-false}" || {
      write_db_state "$key" "ERROR" "$(state_get "db-$key" | sed -n 's/.*"last_completed_phase":"\([^"]*\)".*/\1/p')" "failed in $fn"
      failed=1
    }
  done <<< "$DATABASES_TSV"
  return "$failed"
}

status_dump() {
  if command -v kubectl >/dev/null 2>&1; then
    ensure_state >/dev/null 2>&1 || true
    kubectl get cm "$STATE_CONFIGMAP" -n "$NAMESPACE" -o json 2>/dev/null || echo "{}"
    return 0
  fi
  ensure_state || {
    echo "{}"
    return 0
  }
  kube_api_curl GET "$(state_path)" 2>/dev/null || echo "{}"
}

status_summary() {
  local key source_db target_db rest state phase last err updated_at
  while IFS=$'\t' read -r key source_db target_db rest; do
    [ -z "${key:-}" ] && continue
    phase="$(state_get "db-$key-phase")"
    last="$(state_get "db-$key-last_completed_phase")"
    err="$(state_get "db-$key-last_error")"
    updated_at="$(state_get "db-$key-updated_at")"
    if [ -n "$phase" ]; then
      printf '%s: phase=%s last=%s updated_at=%s error=%s\n' "$key" "$phase" "$last" "$updated_at" "$err"
      continue
    fi
    state="$(state_get "db-$key")"
    if [ -z "$state" ] || [ "$state" = "{\\" ]; then
      printf '%s: phase=NEW last= tables=unknown error=\n' "$key"
    else
      printf '%s\n' "$state" | sed -E 's/.*"phase":"([^"]*)".*"last_completed_phase":"([^"]*)".*"last_error":"([^"]*)".*/'"$key"': phase=\1 last=\2 error=\3/'
    fi
  done <<< "$DATABASES_TSV"
}

main() {
  local rc=0
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

if [ "${MYSQL_DUMP_RESTORE_LIB_ONLY:-false}" != "true" ]; then
  main "$@"
fi

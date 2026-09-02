#!/bin/sh
set -eu

if [ -f /scripts/config.sh ]; then
  . /scripts/config.sh
fi

PHASES="PREFLIGHT PUBLISH SCHEMA LOAD INDEX STEADY"
WORK_DIR="${WORK_DIR:-/work}"
mkdir -p "$WORK_DIR"

need_tools() {
  if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    apk add --no-cache jq curl >/dev/null
  fi
}

current_epoch() {
  date -u '+%s'
}

current_timestamp() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

sanitize_error() {
  jq -Rrs \
    --arg source_admin_password "${SOURCE_ADMIN_PASSWORD:-}" \
    --arg source_repl_password "${SOURCE_REPL_PASSWORD:-}" \
    --arg target_admin_password "${TARGET_ADMIN_PASSWORD:-}" \
    --arg target_repl_password "${TARGET_REPL_PASSWORD:-}" \
    --arg slack_token "${SLACK_TOKEN:-${SLACK_BOT_TOKEN:-}}" \
    '
      def redact($secret):
        if $secret == "" then . else split($secret) | join("[REDACTED]") end;
      gsub("password=[^[:space:]]+"; "password=[REDACTED]")
      | redact($source_admin_password)
      | redact($source_repl_password)
      | redact($target_admin_password)
      | redact($target_repl_password)
      | redact($slack_token)
      | gsub("[\r\n\t ]+"; " ")
      | .[0:500]
    '
}

kube_api() {
  printf 'https://%s:%s' "$KUBERNETES_SERVICE_HOST" "${KUBERNETES_SERVICE_PORT_HTTPS:-443}"
}

kube_curl() {
  method="$1"
  path="$2"
  data="${3:-}"
  k8s_sa_token="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
  k8s_ca_cert=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  if [ -n "$data" ]; then
    curl -fsS --cacert "$k8s_ca_cert" -H "Authorization: Bearer $k8s_sa_token" -H "Content-Type: application/merge-patch+json" -X "$method" --data "$data" "$(kube_api)$path"
  else
    curl -fsS --cacert "$k8s_ca_cert" -H "Authorization: Bearer $k8s_sa_token" -X "$method" "$(kube_api)$path"
  fi
}

state_path() {
  printf '/api/v1/namespaces/%s/configmaps/%s' "$NAMESPACE" "$STATE_CONFIGMAP"
}

ensure_state() {
  if kube_curl GET "$(state_path)" >/tmp/state.json 2>/dev/null; then
    return 0
  fi

  ensure_state_k8s_sa_token="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
  ensure_state_k8s_ca_cert=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  body="$(jq -n --arg name "$STATE_CONFIGMAP" --arg app postgres-replication '{
    apiVersion:"v1",
    kind:"ConfigMap",
    metadata:{name:$name, labels:{"app.kubernetes.io/name":$app}},
    data:{}
  }')"
  curl -fsS --cacert "$ensure_state_k8s_ca_cert" -H "Authorization: Bearer $ensure_state_k8s_sa_token" -H "Content-Type: application/json" -X POST --data "$body" "$(kube_api)/api/v1/namespaces/$NAMESPACE/configmaps" >/dev/null
}

state_get() {
  key="$1"
  ensure_state
  kube_curl GET "$(state_path)" | jq -r --arg key "$key" '.data[$key] // ""'
}

state_patch() {
  key="$1"
  value="$2"
  ensure_state
  patch="$(jq -n --arg key "$key" --arg value "$value" '{data:{($key):$value}}')"
  kube_curl PATCH "$(state_path)" "$patch" >/dev/null
}

state_put() {
  body="$1"
  ensure_state
  k8s_sa_token="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
  k8s_ca_cert=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  curl -fsS --cacert "$k8s_ca_cert" -H "Authorization: Bearer $k8s_sa_token" -H "Content-Type: application/json" -X PUT --data "$body" "$(kube_api)$(state_path)" >/dev/null
}

run_lock_id() {
  printf '%s' "${RUN_LOCK_ID:-${HOSTNAME:-manual}-$$}"
}

lock_selected_dbs() {
  printf '%s' "${SELECTED_DBS:-*}"
}

lock_key() {
  printf 'active_mutation_lock'
}

lock_ttl_seconds() {
  printf '%s' "${RUN_LOCK_TTL_SECONDS:-7200}"
}

active_lock() {
  state_get "$(lock_key)"
}

lock_is_active() {
  lock="$1"
  [ -n "$lock" ] || return 1
  expires_at="$(printf '%s' "$lock" | jq -r '.expires_at_epoch // 0' 2>/dev/null || echo 0)"
  [ "$expires_at" -gt "$(current_epoch)" ]
}

acquire_mutation_lock() {
  mode="$1"
  owner="$(run_lock_id)"
  selected="$(lock_selected_dbs)"
  ttl="$(lock_ttl_seconds)"
  attempts=1
  while [ "$attempts" -le 3 ]; do
    state="$(kube_curl GET "$(state_path)")"
    lock="$(printf '%s' "$state" | jq -r --arg key "$(lock_key)" '.data[$key] // ""')"
    if lock_is_active "$lock"; then
      lock_owner="$(printf '%s' "$lock" | jq -r '.owner // "unknown"' 2>/dev/null || echo unknown)"
      lock_mode="$(printf '%s' "$lock" | jq -r '.mode // "unknown"' 2>/dev/null || echo unknown)"
      lock_selected="$(printf '%s' "$lock" | jq -r '.selected_dbs // "*"' 2>/dev/null || echo '*')"
      lock_expires="$(printf '%s' "$lock" | jq -r '.expires_at // "unknown"' 2>/dev/null || echo unknown)"
      echo "REFUSED: another mutating replication action is active owner=$lock_owner mode=$lock_mode selected_dbs=$lock_selected expires_at=$lock_expires" >&2
      return 1
    fi
    now_epoch="$(current_epoch)"
    expires_epoch=$((now_epoch + ttl))
    lock_payload="$(jq -cn \
      --arg owner "$owner" \
      --arg mode "$mode" \
      --arg selected_dbs "$selected" \
      --arg started_at "$(current_timestamp)" \
      --argjson started_at_epoch "$now_epoch" \
      --argjson expires_at_epoch "$expires_epoch" \
      '{owner:$owner,mode:$mode,selected_dbs:$selected_dbs,started_at:$started_at,started_at_epoch:$started_at_epoch,expires_at_epoch:$expires_at_epoch}')"
    updated="$(printf '%s' "$state" | jq --arg key "$(lock_key)" --arg value "$lock_payload" '.data = (.data // {}) | .data[$key] = $value')"
    if state_put "$updated" 2>/dev/null; then
      return 0
    fi
    attempts=$((attempts + 1))
    sleep 1
  done
  echo "REFUSED: could not acquire mutation lock after retries" >&2
  return 1
}

release_mutation_lock() {
  owner="$(run_lock_id)"
  attempts=1
  while [ "$attempts" -le 3 ]; do
    state="$(kube_curl GET "$(state_path)" 2>/dev/null || true)"
    [ -n "$state" ] || return 0
    lock="$(printf '%s' "$state" | jq -r --arg key "$(lock_key)" '.data[$key] // ""')"
    [ -n "$lock" ] || return 0
    lock_owner="$(printf '%s' "$lock" | jq -r '.owner // ""' 2>/dev/null || true)"
    [ "$lock_owner" = "$owner" ] || return 0
    updated="$(printf '%s' "$state" | jq --arg key "$(lock_key)" 'del(.data[$key])')"
    if state_put "$updated" 2>/dev/null; then
      return 0
    fi
    attempts=$((attempts + 1))
    sleep 1
  done
  return 0
}

require_no_mutation_lock() {
  lock="$(active_lock)"
  if lock_is_active "$lock"; then
    lock_owner="$(printf '%s' "$lock" | jq -r '.owner // "unknown"' 2>/dev/null || echo unknown)"
    lock_mode="$(printf '%s' "$lock" | jq -r '.mode // "unknown"' 2>/dev/null || echo unknown)"
    echo "REFUSED: mutating replication action is active owner=$lock_owner mode=$lock_mode" >&2
    return 1
  fi
}

db_json() {
  db_key="$1"
  printf '%s' "$DATABASES_JSON" | jq -c --arg name "$db_key" '.[] | select(.name == $name)'
}

db_keys() {
  if [ -n "${SELECTED_DBS:-}" ]; then
    printf '%s\n' "$SELECTED_DBS" | tr ',' '\n' | while IFS= read -r selected; do
      selected="$(printf '%s' "$selected" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      [ -n "$selected" ] || continue
      if ! printf '%s' "$DATABASES_JSON" | jq -e --arg name "$selected" '.[] | select(.name == $name)' >/dev/null; then
        echo "unknown selected database: $selected" >&2
        return 1
      fi
      printf '%s\n' "$selected"
    done
    return $?
  fi
  printf '%s' "$DATABASES_JSON" | jq -r '.[].name'
}

db_field() {
  db_key="$1"
  field="$2"
  db_json "$db_key" | jq -r --arg field "$field" '.[$field]'
}

db_array_json() {
  db_key="$1"
  field="$2"
  db_json "$db_key" | jq -c --arg field "$field" '.[$field] // []'
}

phase_index() {
  phase="$1"
  index=0
  for p in $PHASES; do
    if [ "$p" = "$phase" ]; then
      echo "$index"
      return 0
    fi
    index=$((index + 1))
  done
  echo "-1"
}

last_completed() {
  db_key="$1"
  current="$(state_get "db-$db_key")"
  if [ -z "$current" ]; then
    echo "NONE"
  else
    printf '%s' "$current" | jq -r '.last_completed_phase // "NONE"'
  fi
}

build_db_state() {
  db_key="$1"
  phase="$2"
  last="$3"
  error="$4"
  tables_total="${5:-0}"
  tables_ready="${6:-0}"
  record_duration="${7:-false}"
  publication="$(db_field "$db_key" publication)"
  subscription="$(db_field "$db_key" subscription)"
  existing="$(state_get "db-$db_key")"
  phase_started_epoch="$(printf '%s' "$existing" | jq -r --arg phase "$phase" 'if .phase == $phase and (.phase_started_epoch // "") != "" then .phase_started_epoch else empty end' 2>/dev/null || true)"
  if [ -z "$phase_started_epoch" ]; then
    phase_started_epoch="$(current_epoch)"
  fi
  phase_started_at="$(printf '%s' "$existing" | jq -r --arg phase "$phase" 'if .phase == $phase and (.phase_started_at // "") != "" then .phase_started_at else empty end' 2>/dev/null || true)"
  if [ -z "$phase_started_at" ]; then
    phase_started_at="$(current_timestamp)"
  fi
  if [ -n "$existing" ]; then
    existing_durations="$(printf '%s' "$existing" | jq -c '.phase_durations // {}' 2>/dev/null || printf '{}')"
  else
    existing_durations="{}"
  fi
  if [ "$record_duration" = "true" ] && [ "$phase" = "$last" ]; then
    elapsed=$(( $(current_epoch) - phase_started_epoch ))
    if [ "$elapsed" -lt 0 ]; then
      elapsed=0
    fi
    phase_durations="$(printf '%s' "$existing_durations" | jq -c --arg phase "$phase" --argjson elapsed "$elapsed" '. + {($phase): $elapsed}')"
  else
    phase_durations="$existing_durations"
  fi
  skipped_foreign_keys="$(db_array_json "$db_key" exclude_foreign_keys)"

	  jq -n \
	    --arg phase "$phase" \
	    --arg last "$last" \
	    --arg error "$error" \
	    --arg publication "$publication" \
	    --arg subscription "$subscription" \
	    --arg slot "$subscription" \
	    --arg rebaseline_id "${REBASELINE_ID:-}" \
	    --arg source_host "${SOURCE_HOST:-}" \
	    --arg target_host "${TARGET_HOST:-}" \
	    --arg phase_started_at "$phase_started_at" \
	    --argjson phase_started_epoch "$phase_started_epoch" \
	    --argjson phase_durations "$phase_durations" \
	    --argjson tables_total "$tables_total" \
	    --argjson tables_ready "$tables_ready" \
	    --argjson skipped_foreign_keys "$skipped_foreign_keys" \
	    '{phase:$phase,last_completed_phase:$last,phase_started_at:$phase_started_at,phase_started_epoch:$phase_started_epoch,phase_durations:$phase_durations,tables_total:$tables_total,tables_ready:$tables_ready,publication:$publication,subscription:$subscription,slot:$slot,rebaseline_id:$rebaseline_id,source_host:$source_host,target_host:$target_host,last_error:$error,skipped_foreign_keys:$skipped_foreign_keys}'
}

write_db_state() {
  db_key="$1"
  phase="$2"
  last="$3"
  error="$4"
  tables_total="${5:-0}"
  tables_ready="${6:-0}"
  record_duration="${7:-false}"
  value="$(build_db_state "$db_key" "$phase" "$last" "$error" "$tables_total" "$tables_ready" "$record_duration")"
  state_patch "db-$db_key" "$value"
}

source_psql() {
  db="$1"
  shift
  PGSSLMODE=require PGPASSWORD="$SOURCE_ADMIN_PASSWORD" psql -v ON_ERROR_STOP=1 -h "$SOURCE_HOST" -p "$SOURCE_PORT" -U "$SOURCE_ADMIN_USER" -d "$db" "$@"
}

source_auth_db_for() {
  db="$1"
  if [ -n "${SOURCE_AUTH_DB:-}" ]; then
    echo "$SOURCE_AUTH_DB"
  else
    echo "$db"
  fi
}

source_auth_psql() {
  db="$1"
  shift
  auth_db="$(source_auth_db_for "$db")"
  PGSSLMODE=require PGPASSWORD="$SOURCE_ADMIN_PASSWORD" psql -v ON_ERROR_STOP=1 -h "$SOURCE_HOST" -p "$SOURCE_PORT" -U "$SOURCE_ADMIN_USER" -d "$auth_db" "$@"
}

source_repl_psql() {
  db="$1"
  shift
  PGSSLMODE=require PGPASSWORD="$SOURCE_REPL_PASSWORD" psql -v ON_ERROR_STOP=1 -h "$SOURCE_HOST" -p "$SOURCE_PORT" -U "$SOURCE_REPL_USER" -d "$db" "$@"
}

preflight_source_repl_timeouts() {
  db_key="$1"
  source_db="$(db_field "$db_key" source_db)"

  echo "-- source replication user effective settings"
  settings="$(source_repl_psql "$source_db" -Atc "select 'statement_timeout=' || current_setting('statement_timeout'); select 'idle_in_transaction_session_timeout=' || current_setting('idle_in_transaction_session_timeout'); select 'lock_timeout=' || current_setting('lock_timeout');")"
  printf '%s\n' "$settings" | sed 's/^/source_repl_setting /'

  statement_timeout="$(printf '%s\n' "$settings" | awk -F= '$1 == "statement_timeout" {print $2; exit}')"
  idle_timeout="$(printf '%s\n' "$settings" | awk -F= '$1 == "idle_in_transaction_session_timeout" {print $2; exit}')"
  lock_timeout="$(printf '%s\n' "$settings" | awk -F= '$1 == "lock_timeout" {print $2; exit}')"

  if [ "$statement_timeout" != "0" ]; then
    echo "REFUSED: source replication user statement_timeout must be 0"
    return 1
  fi
  if [ "$idle_timeout" != "0" ]; then
    echo "REFUSED: source replication user idle_in_transaction_session_timeout must be 0"
    return 1
  fi
  if [ "$lock_timeout" != "0" ]; then
    echo "REFUSED: source replication user lock_timeout must be 0"
    return 1
  fi
}

sanitize_pg_dump_sql() {
  db_key="${1:-}"
  exclude_extensions="[]"
  if [ -n "$db_key" ]; then
    exclude_extensions="$(db_array_json "$db_key" exclude_extensions)"
  fi
  excluded="$(printf '%s' "$exclude_extensions" | jq -r '.[]?' | tr '\n' ' ')"
  awk -v db_key="$db_key" -v excluded="$excluded" '
    function normalized_ext(line, prefix, ext) {
      ext = line
      gsub(/"/, "", ext)
      sub(prefix, "", ext)
      sub(/[ \t;].*/, "", ext)
      return ext
    }
    function is_excluded(ext) {
      return index(" " excluded " ", " " ext " ") > 0
    }
    function is_known_unsupported(ext) {
      return ext == "aws_commons" || ext == "aws_s3"
    }
    /^SET transaction_timeout = / {
      next
    }
    /^CREATE EXTENSION( IF NOT EXISTS)?[ \t]+/ {
      ext = normalized_ext($0, "^CREATE EXTENSION( IF NOT EXISTS)?[ \t]+")
      if (is_excluded(ext)) {
        print "WARNING: skipping excluded extension " ext " for " db_key > "/dev/stderr"
        next
      }
      if (is_known_unsupported(ext)) {
        print "REFUSED: unsupported extension " ext " in source schema. Add databases." db_key ".exclude_extensions=[\"" ext "\"] only after confirming no DB objects depend on it." > "/dev/stderr"
        exit 42
      }
    }
    /^COMMENT ON EXTENSION[ \t]+/ {
      ext = normalized_ext($0, "^COMMENT ON EXTENSION[ \t]+")
      if (is_excluded(ext)) {
        next
      }
    }
    {
      print
    }
  '
}

split_post_data_sql() {
  db_key="$1"
  post="$2"
  primary="$3"
  secondary="$4"
  target_relations_file="${5:-}"
  primary_relations_file="${6:-}"
  excluded_tables="$(db_array_json "$db_key" exclude_tables | jq -r '.[]?' | tr '\n' ' ')"
  excluded_schemas="$(db_array_json "$db_key" exclude_schemas | jq -r '.[]?' | tr '\n' ' ')"
  excluded_foreign_keys="$(db_array_json "$db_key" exclude_foreign_keys | jq -r '.[]?' | tr '\n' ' ')"
  target_relations=""
  if [ -n "$target_relations_file" ] && [ -f "$target_relations_file" ]; then
    target_relations="$(tr '\n' ' ' < "$target_relations_file")"
  fi
  primary_relations=""
  if [ -n "$primary_relations_file" ] && [ -f "$primary_relations_file" ]; then
    primary_relations="$(tr '\n' ' ' < "$primary_relations_file")"
  fi
  awk -v primary_out="$primary" -v secondary_out="$secondary" -v fk_validation_mode="${FOREIGN_KEY_VALIDATION_MODE:-strict}" -v excluded_tables="$excluded_tables" -v excluded_schemas="$excluded_schemas" -v excluded_foreign_keys="$excluded_foreign_keys" -v target_relations="$target_relations" -v primary_relations="$primary_relations" '
    function quote_literal(value, q) {
      q = sprintf("%c", 39)
      gsub(q, q q, value)
      return q value q
    }
    function unquote_ident(value) {
      gsub(/"/, "", value)
      return value
    }
    function constraint_table(text, first_line) {
      first_line = text
      sub(/\n.*/, "", first_line)
      sub(/^ALTER TABLE[ \t]+(ONLY[ \t]+)?/, "", first_line)
      sub(/[ \t\r\n]*$/, "", first_line)
      return unquote_ident(first_line)
    }
    function index_table(text, first_line) {
      first_line = text
      sub(/\n.*/, "", first_line)
      sub(/^CREATE( UNIQUE)? INDEX( CONCURRENTLY)?( IF NOT EXISTS)?[ \t]+[^ \t]+[ \t]+ON[ \t]+(ONLY[ \t]+)?/, "", first_line)
      sub(/[ \t\r\n].*/, "", first_line)
      return unquote_ident(first_line)
    }
    function trigger_table(text, first_line) {
      first_line = text
      sub(/\n.*/, "", first_line)
      sub(/.*[ \t]+ON[ \t]+/, "", first_line)
      sub(/[ \t\r\n].*/, "", first_line)
      return unquote_ident(first_line)
    }
    function statistics_table(text, relation) {
      relation = text
      sub(/.*[ \t]+FROM[ \t]+/, "", relation)
      sub(/[ \t\r\n;].*/, "", relation)
      return unquote_ident(relation)
    }
    function block_table(text) {
      if (text ~ /^ALTER TABLE/) {
        return constraint_table(text)
      }
      if (text ~ /^CREATE INDEX/ || text ~ /^CREATE UNIQUE INDEX/) {
        return index_table(text)
      }
      if (text ~ /^CREATE TRIGGER/) {
        return trigger_table(text)
      }
      if (text ~ /^CREATE STATISTICS/) {
        return statistics_table(text)
      }
      return ""
    }
    function attach_partition_relation(text, relation) {
      if (text !~ /ATTACH PARTITION[ \t]+/) {
        return ""
      }
      relation = text
      sub(/.*ATTACH PARTITION[ \t]+/, "", relation)
      sub(/[ \t\r\n;].*/, "", relation)
      return unquote_ident(relation)
    }
    function relation_exists(relation) {
      return relation == "" || target_relations == "" || index(" " target_relations " ", " " relation " ") > 0
    }
    function primary_relation_ready(relation) {
      return relation == "" || primary_relations == "" || index(" " primary_relations " ", " " relation " ") > 0
    }
    function table_schema(table_name, schema) {
      schema = table_name
      sub(/\..*/, "", schema)
      return schema
    }
    function is_excluded_block(text, table_name, schema) {
      table_name = block_table(text)
      if (table_name == "") {
        return 0
      }
      schema = table_schema(table_name)
      return index(" " excluded_tables " ", " " table_name " ") > 0 || index(" " excluded_schemas " ", " " schema " ") > 0
    }
    function is_missing_target_relation_block(text, table_name, partition_relation) {
      table_name = block_table(text)
      partition_relation = attach_partition_relation(text)
      return !relation_exists(table_name) || !relation_exists(partition_relation)
    }
    function constraint_name(text, name) {
      name = text
      sub(/.*ADD CONSTRAINT[ \t\r\n]+/, "", name)
      sub(/[ \t\r\n].*/, "", name)
      gsub(/"/, "", name)
      return name
    }
    function foreign_key_identifier(text) {
      if (text !~ /ADD CONSTRAINT .* FOREIGN KEY/) {
        return ""
      }
      return constraint_table(text) "." constraint_name(text)
    }
    function is_excluded_foreign_key(text, identifier) {
      identifier = foreign_key_identifier(text)
      return identifier != "" && index(" " excluded_foreign_keys " ", " " identifier " ") > 0
    }
    function trigger_name(text, name) {
      name = text
      sub(/^CREATE TRIGGER[ \t]+/, "", name)
      sub(/[ \t\r\n].*/, "", name)
      gsub(/"/, "", name)
      return name
    }
    function idempotent_constraint(text, table_name, name) {
      table_name = constraint_table(text)
      name = constraint_name(text)
      return "DO $facets$\nBEGIN\n  IF to_regclass(" quote_literal(table_name) ") IS NULL OR NOT EXISTS (\n    SELECT 1 FROM pg_constraint\n    WHERE conname = " quote_literal(name) "\n      AND conrelid = to_regclass(" quote_literal(table_name) ")\n  ) THEN\n    EXECUTE " quote_literal(text) ";\n  END IF;\nEND\n$facets$;\n"
    }
    function idempotent_trigger(text, table_name, name) {
      table_name = trigger_table(text)
      name = trigger_name(text)
      return "DO $facets$\nBEGIN\n  IF to_regclass(" quote_literal(table_name) ") IS NOT NULL AND NOT EXISTS (\n    SELECT 1 FROM pg_trigger\n    WHERE tgname = " quote_literal(name) "\n      AND tgrelid = to_regclass(" quote_literal(table_name) ")\n  ) THEN\n    EXECUTE " quote_literal(text) ";\n  END IF;\nEND\n$facets$;\n"
    }
    function not_valid_foreign_key(text, normalized) {
      if (fk_validation_mode != "not_valid" || text !~ /ADD CONSTRAINT .* FOREIGN KEY/) {
        return text
      }
      normalized = text
      sub(/[ \t\r\n]*;[ \t\r\n]*$/, "", normalized)
      if (normalized !~ / NOT VALID$/) {
        normalized = normalized " NOT VALID"
      }
      return normalized ";\n"
    }
    function idempotent_index(text) {
      if (text ~ /^CREATE UNIQUE INDEX /) {
        if (text ~ / ON ONLY /) {
          sub(/^CREATE UNIQUE INDEX /, "CREATE UNIQUE INDEX IF NOT EXISTS ", text)
        } else {
          sub(/^CREATE UNIQUE INDEX /, "CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS ", text)
        }
      } else if (text ~ /^CREATE INDEX /) {
        if (text ~ / ON ONLY /) {
          sub(/^CREATE INDEX /, "CREATE INDEX IF NOT EXISTS ", text)
        } else {
          sub(/^CREATE INDEX /, "CREATE INDEX CONCURRENTLY IF NOT EXISTS ", text)
        }
      }
      return text
    }
    function idempotent_statistics(text) {
      if (text ~ /^CREATE STATISTICS /) {
        sub(/^CREATE STATISTICS /, "CREATE STATISTICS IF NOT EXISTS ", text)
      }
      return text
    }
    function emit(text) {
      if (text == "") {
        return
      }
      if (is_excluded_block(text)) {
        return
      }
      if (is_excluded_foreign_key(text)) {
        print "WARNING: skipping excluded foreign key " foreign_key_identifier(text) > "/dev/stderr"
        return
      }
      if (is_missing_target_relation_block(text)) {
        return
      }
      if (text ~ /ADD CONSTRAINT .* PRIMARY KEY/) {
        table_name = constraint_table(text)
        if (primary_relation_ready(table_name)) {
          printf "%s", idempotent_constraint(text) >> primary_out
        }
      } else {
        if (text ~ /ADD CONSTRAINT /) {
          text = not_valid_foreign_key(text)
          text = idempotent_constraint(text)
        } else if (text ~ /^CREATE TRIGGER/) {
          text = idempotent_trigger(text)
        } else if (text ~ /^CREATE STATISTICS /) {
          text = idempotent_statistics(text)
        } else if (text ~ /^CREATE INDEX / || text ~ /^CREATE UNIQUE INDEX /) {
          text = idempotent_index(text)
        }
        printf "%s", text >> secondary_out
      }
    }
    function flush_block() {
      emit(buf)
      buf=""
      collecting=0
    }
    /^ALTER TABLE/ || /^ALTER INDEX/ || /^CREATE INDEX/ || /^CREATE UNIQUE INDEX/ || /^CREATE TRIGGER/ || /^CREATE STATISTICS/ {
      collecting=1
      buf=$0 "\n"
      if (/;$/) flush_block()
      next
    }
    /^CREATE PUBLICATION/ || /^ALTER PUBLICATION/ || /^CREATE SUBSCRIPTION/ || /^ALTER SUBSCRIPTION/ {
      collecting_skip=1
      if (/;$/) collecting_skip=0
      next
    }
    collecting_skip {
      if (/;$/) collecting_skip=0
      next
    }
    collecting {
      buf=buf $0 "\n"
      if (/;$/) flush_block()
      next
    }
    { print >> secondary_out }
    END {
      if (collecting) {
        flush_block()
      }
    }
  ' "$post"
}

target_psql() {
  db="$1"
  shift
  PGSSLMODE=require PGPASSWORD="$TARGET_ADMIN_PASSWORD" psql -v ON_ERROR_STOP=1 -h "$TARGET_HOST" -p "$TARGET_PORT" -U "$TARGET_ADMIN_USER" -d "$db" "$@"
}

runtime_write_guard() {
  if [ "${SOURCE_HOST:-}" = "${TARGET_HOST:-}" ]; then
    echo "REFUSED: source and target hosts are identical" >&2
    return 1
  fi
  if [ "${ALLOW_MUTATION:-true}" != "true" ]; then
    echo "REFUSED: mutating replication actions are disabled by options.allow_mutation=false" >&2
    return 1
  fi
}

target_login_role_count() {
  printf '%s' "${TARGET_LOGIN_ROLES_JSON:-[]}" | jq 'length'
}

is_protected_target_role() {
  role="$1"
  case "$role" in
    "" | "0" | public | postgres | rdsadmin | rds_superuser | rds_replication | pg_*)
      return 0
      ;;
  esac
  [ "$role" = "${TARGET_ADMIN_USER:-}" ] && return 0
  [ "$role" = "${TARGET_REPL_USER:-}" ] && return 0
  return 1
}

require_target_login_roles_configured() {
  if [ "${REQUIRE_TARGET_LOGIN_ROLES:-true}" = "true" ] && [ "$(target_login_role_count)" = "0" ]; then
    echo "REFUSED: target.login_roles is empty. Run discover-roles and add required roles to spec.target.login_roles before migration."
    return 1
  fi
}

ensure_target_login_roles() {
  db_key="$1"
  target_db="$(db_field "$db_key" target_db)"
  mode="${TARGET_LOGIN_ROLE_MODE:-manage}"
  case "$mode" in
    manage | create_missing | skip) ;;
    *)
      echo "REFUSED: invalid TARGET_LOGIN_ROLE_MODE=$mode; expected manage, create_missing, or skip" >&2
      return 1
      ;;
  esac
  if [ "$mode" = "skip" ]; then
    echo "target_login_role_mode_skip"
    return 0
  fi
  roles="$(printf '%s' "${TARGET_LOGIN_ROLES_JSON:-[]}" | jq -r '.[]')"
  passwords_json="${TARGET_LOGIN_ROLE_PASSWORDS_JSON:-}"
  [ -n "$passwords_json" ] || passwords_json="{}"
  [ -n "$roles" ] || return 0
  for role in $roles; do
    [ -n "$role" ] || continue
    if is_protected_target_role "$role"; then
      echo "target_login_role_skip_protected role=$role"
      continue
    fi
    if [ "$mode" = "create_missing" ]; then
      exists="$(target_psql "$target_db" -v role="$role" -Atc "SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'role');" | tr -d '[:space:]')"
      if [ "$exists" = "t" ] || [ "$exists" = "true" ]; then
        echo "target_login_role_exists role=$role"
        continue
      fi
      password="$(printf '%s' "$passwords_json" | jq -r --arg role "$role" '.[$role] // ""')"
      if [ -z "$password" ]; then
        echo "REFUSED: missing generated password for target login role $role" >&2
        return 1
      fi
      echo "target_login_role_create role=$role"
      target_psql "$target_db" -v role="$role" -v password="$password" <<'SQL'
SELECT format('CREATE ROLE %I WITH LOGIN PASSWORD %L', :'role', :'password') \gexec
SQL
      continue
    fi
    password="$(printf '%s' "$passwords_json" | jq -r --arg role "$role" '.[$role] // ""')"
    if [ -z "$password" ]; then
      echo "REFUSED: missing generated password for target login role $role" >&2
      return 1
    fi
    echo "target_login_role role=$role"
    target_psql "$target_db" -v role="$role" -v password="$password" <<'SQL'
SELECT CASE
  WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'role')
  THEN format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'role', :'password')
  ELSE format('CREATE ROLE %I WITH LOGIN PASSWORD %L', :'role', :'password')
END \gexec
SQL
  done
}

discover_roles_db() {
  db_key="$1"
  source_db="$(db_field "$db_key" source_db)"
  source_psql "$source_db" -Atc "
WITH candidates(role_name) AS (
  SELECT r.rolname
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_roles r ON r.oid = c.relowner
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_temp_'
    AND n.nspname !~ '^pg_toast_temp_'
    AND c.relkind IN ('r','p','v','m','S','f')
  UNION
  SELECT r.rolname
  FROM pg_namespace n
  JOIN pg_roles r ON r.oid = n.nspowner
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_temp_'
    AND n.nspname !~ '^pg_toast_temp_'
  UNION
  SELECT r.rolname
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_roles r ON r.oid = p.proowner
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_temp_'
    AND n.nspname !~ '^pg_toast_temp_'
  UNION
  SELECT pg_get_userbyid(acl.grantee)
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  CROSS JOIN LATERAL aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) acl
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_temp_'
    AND n.nspname !~ '^pg_toast_temp_'
    AND c.relkind IN ('r','p','v','m','S','f')
    AND acl.grantee <> 0
  UNION
  SELECT pg_get_userbyid(acl.grantee)
  FROM pg_namespace n
  CROSS JOIN LATERAL aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) acl
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_temp_'
    AND n.nspname !~ '^pg_toast_temp_'
    AND acl.grantee <> 0
  UNION
  SELECT pg_get_userbyid(acl.grantee)
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  CROSS JOIN LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_temp_'
    AND n.nspname !~ '^pg_toast_temp_'
    AND acl.grantee <> 0
  UNION
  SELECT pg_get_userbyid(acl.grantee)
  FROM pg_default_acl d
  JOIN pg_namespace n ON n.oid = d.defaclnamespace
  CROSS JOIN LATERAL aclexplode(d.defaclacl) acl
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_temp_'
    AND n.nspname !~ '^pg_toast_temp_'
    AND acl.grantee <> 0
)
SELECT DISTINCT role_name
FROM candidates
WHERE role_name IS NOT NULL
  AND role_name <> ''
  AND role_name <> '0'
  AND role_name <> 'public'
  AND role_name <> 'postgres'
  AND role_name <> current_user
  AND role_name <> '$SOURCE_ADMIN_USER'
  AND role_name <> '$SOURCE_REPL_USER'
  AND role_name <> 'rdsadmin'
  AND role_name <> 'rds_superuser'
  AND role_name <> 'rds_replication'
  AND role_name !~ '^pg_'
ORDER BY role_name;"
}

discover_roles() {
  tmp="$WORK_DIR/discovered-roles.txt"
  : > "$tmp"
  for db_key in $(db_keys); do
    echo "== DISCOVER ROLES $db_key ==" >&2
    discover_roles_db "$db_key" >> "$tmp"
  done
  echo "target:"
  echo "  login_roles:"
  sed 's/^"//; s/"$//' "$tmp" | sort -u | while IFS= read -r role; do
    case "$role" in
      "" | "0" | "-" | "unknown (OID=0)" | public | postgres | rdsadmin | rds_superuser | rds_replication | "$SOURCE_ADMIN_USER" | "$SOURCE_REPL_USER" | pg_*)
        continue
        ;;
    esac
    printf '    - %s\n' "$(printf '%s' "$role" | jq -Rr '@json')"
  done
}

target_existing_roles() {
  target_db="$1"
  target_psql "$target_db" -Atc "SELECT rolname FROM pg_roles ORDER BY rolname;"
}

target_existing_grant_objects() {
  target_db="$1"
  target_psql "$target_db" -At <<'SQL'
SELECT 'schema:' || nspname AS grant_object_key
FROM pg_namespace
WHERE nspname NOT IN ('pg_catalog', 'information_schema')
  AND nspname !~ '^pg_temp_'
  AND nspname !~ '^pg_toast_temp_'
UNION ALL
SELECT 'rel:' || n.nspname || '.' || c.relname AS grant_object_key
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND n.nspname !~ '^pg_temp_'
  AND n.nspname !~ '^pg_toast_temp_'
  AND c.relkind IN ('r','p','v','m','S','f')
UNION ALL
SELECT 'func:' || p.oid::regprocedure::text AS grant_object_key
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND n.nspname !~ '^pg_temp_'
  AND n.nspname !~ '^pg_toast_temp_'
ORDER BY grant_object_key;
SQL
}

role_in_file() {
  role="$1"
  file="$2"
  grep -Fx -- "$role" "$file" >/dev/null 2>&1
}

line_in_file() {
  line="$1"
  file="$2"
  grep -Fx -- "$line" "$file" >/dev/null 2>&1
}

source_grant_rows_db() {
  db_key="$1"
  source_db="$(db_field "$db_key" source_db)"
  source_psql "$source_db" -F "$(printf '\t')" -At <<'SQL'
WITH rel_acl AS (
  SELECT
    pg_get_userbyid(acl.grantee) AS grantee,
    ''::text AS member,
    'rel:' || n.nspname || '.' || c.relname AS object_key,
    format(
      'GRANT %s ON %s %I.%I TO %I;',
      string_agg(DISTINCT acl.privilege_type, ',' ORDER BY acl.privilege_type),
      CASE WHEN c.relkind = 'S' THEN 'SEQUENCE' ELSE 'TABLE' END,
      n.nspname,
      c.relname,
      pg_get_userbyid(acl.grantee)
    ) AS grant_sql
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  CROSS JOIN LATERAL aclexplode(coalesce(c.relacl, acldefault(CASE WHEN c.relkind = 'S' THEN 'S'::"char" ELSE 'r'::"char" END, c.relowner))) acl
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_temp_'
    AND n.nspname !~ '^pg_toast_temp_'
    AND c.relkind IN ('r','p','v','m','S','f')
    AND acl.grantee <> 0
  GROUP BY pg_get_userbyid(acl.grantee), c.relkind, n.nspname, c.relname
),
schema_acl AS (
  SELECT
    pg_get_userbyid(acl.grantee) AS grantee,
    ''::text AS member,
    'schema:' || n.nspname AS object_key,
    format(
      'GRANT %s ON SCHEMA %I TO %I;',
      string_agg(DISTINCT acl.privilege_type, ',' ORDER BY acl.privilege_type),
      n.nspname,
      pg_get_userbyid(acl.grantee)
    ) AS grant_sql
  FROM pg_namespace n
  CROSS JOIN LATERAL aclexplode(coalesce(n.nspacl, acldefault('n'::"char", n.nspowner))) acl
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_temp_'
    AND n.nspname !~ '^pg_toast_temp_'
    AND acl.grantee <> 0
  GROUP BY pg_get_userbyid(acl.grantee), n.nspname
),
function_acl AS (
  SELECT
    pg_get_userbyid(acl.grantee) AS grantee,
    ''::text AS member,
    'func:' || p.oid::regprocedure::text AS object_key,
    format(
      'GRANT %s ON FUNCTION %s TO %I;',
      string_agg(DISTINCT acl.privilege_type, ',' ORDER BY acl.privilege_type),
      p.oid::regprocedure,
      pg_get_userbyid(acl.grantee)
    ) AS grant_sql
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  CROSS JOIN LATERAL aclexplode(coalesce(p.proacl, acldefault('f'::"char", p.proowner))) acl
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_temp_'
    AND n.nspname !~ '^pg_toast_temp_'
    AND acl.grantee <> 0
  GROUP BY pg_get_userbyid(acl.grantee), p.oid
),
membership_acl AS (
  SELECT
    granted.rolname AS grantee,
    member.rolname AS member,
    'membership:' || granted.rolname || ':' || member.rolname AS object_key,
    format('GRANT %I TO %I;', granted.rolname, member.rolname) AS grant_sql
  FROM pg_auth_members m
  JOIN pg_roles granted ON granted.oid = m.roleid
  JOIN pg_roles member ON member.oid = m.member
)
SELECT grantee, member, object_key, grant_sql FROM rel_acl
UNION ALL
SELECT grantee, member, object_key, grant_sql FROM schema_acl
UNION ALL
SELECT grantee, member, object_key, grant_sql FROM function_acl
UNION ALL
SELECT grantee, member, object_key, grant_sql FROM membership_acl
ORDER BY grantee, member, object_key, grant_sql;
SQL
}

build_match_grants_sql() {
  db_key="$1"
  target_db="$(db_field "$db_key" target_db)"
  target_roles="$WORK_DIR/$db_key-target-roles.txt"
  target_objects="$WORK_DIR/$db_key-target-grant-objects.txt"
  grant_rows="$WORK_DIR/$db_key-source-grant-rows.tsv"
  grant_sql="$WORK_DIR/$db_key-match-grants.sql"

  target_existing_roles "$target_db" > "$target_roles" || return 1
  target_existing_grant_objects "$target_db" > "$target_objects" || return 1
  source_grant_rows_db "$db_key" > "$grant_rows" || return 1
  : > "$grant_sql"
  while IFS="$(printf '\t')" read -r role member object_key sql; do
    [ -n "$role" ] || continue
    if [ -z "${sql:-}" ] && [ -n "${object_key:-}" ]; then
      sql="$object_key"
      object_key="$member"
      member=""
    fi
    if is_protected_target_role "$role"; then
      echo "grant_skip_protected role=$role" >&2
      continue
    fi
    if ! role_in_file "$role" "$target_roles"; then
      echo "grant_skip_missing_target_role role=$role" >&2
      continue
    fi
    if [ -n "$member" ]; then
      if is_protected_target_role "$member"; then
        echo "grant_skip_protected member=$member" >&2
        continue
      fi
      if ! role_in_file "$member" "$target_roles"; then
        echo "grant_skip_missing_target_member member=$member" >&2
        continue
      fi
    fi
    case "$object_key" in
      membership:*)
        ;;
      *)
        if ! line_in_file "$object_key" "$target_objects"; then
          echo "grant_skip_missing_target_object object=$object_key" >&2
          continue
        fi
        ;;
    esac
    printf '%s\n' "$sql" >> "$grant_sql"
  done < "$grant_rows"
  printf '%s\n' "$grant_sql"
}

match_grants_dryrun_db() {
  db_key="$1"
  target_db="$(db_field "$db_key" target_db)"
  echo "== MATCH GRANTS DRYRUN $db_key =="
  grant_sql="$(build_match_grants_sql "$db_key")" || return 1
  echo "grant_dryrun db=$target_db statements=$(wc -l < "$grant_sql" | tr -d ' ')"
  cat "$grant_sql"
}

match_grants_db() {
  db_key="$1"
  target_db="$(db_field "$db_key" target_db)"
  echo "== MATCH GRANTS $db_key =="
  runtime_write_guard || return 1

  grant_sql="$(build_match_grants_sql "$db_key")" || return 1

  if [ -s "$grant_sql" ]; then
    echo "grant_apply db=$target_db statements=$(wc -l < "$grant_sql" | tr -d ' ')"
    target_psql "$target_db" -f "$grant_sql"
  else
    echo "grant_apply db=$target_db statements=0"
  fi
}

target_public_objects() {
  target_db="$1"
  target_schema_objects "$target_db" public
}

sql_quote_ident() {
  printf '%s' "$1" | sed 's/"/""/g; s/^/"/; s/$/"/'
}

dump_schema_names() {
  pre_file="${1:-}"
  {
    echo public
    if [ -n "$pre_file" ] && [ -f "$pre_file" ]; then
      sed -nE 's/^[[:space:]]*CREATE SCHEMA[[:space:]]+(IF NOT EXISTS[[:space:]]+)?("[^"]+"|[A-Za-z_][A-Za-z0-9_$]*)[[:space:]]*;.*/\2/p' "$pre_file" |
        sed 's/^"//; s/"$//; s/""/"/g'
    fi
  } | sed '/^$/d' | sort -u
}

target_schema_objects() {
  target_db="$1"
  schema="$2"
  target_psql "$target_db" -v schema="$schema" -At <<'SQL'
    select object_name
    from (
      select n.nspname || '.*' as object_name
      from pg_namespace n
      where n.nspname = :'schema'
        and n.nspname <> 'public'
      union all
      select n.nspname || '.' || c.relname as object_name
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = :'schema'
        and c.relkind in ('r','p','v','m','S','f')
      union all
      select n.nspname || '.' || p.proname || '()' as object_name
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = :'schema'
      union all
      select n.nspname || '.' || e.extname as object_name
      from pg_extension e
      join pg_namespace n on n.oid = e.extnamespace
      where n.nspname = :'schema'
    ) objects
    order by object_name;
SQL
}

target_reset_objects() {
  target_db="$1"
  pre_file="${2:-}"
  for schema in $(dump_schema_names "$pre_file"); do
    if [ "$schema" = "public" ]; then
      target_public_objects "$target_db"
    else
      target_schema_objects "$target_db" "$schema"
    fi
  done
}

schema_drop_sql() {
  pre_file="${1:-}"
  for schema in $(dump_schema_names "$pre_file"); do
    if [ "$schema" = "public" ]; then
      echo 'DROP SCHEMA IF EXISTS public CASCADE;'
    else
      printf 'DROP SCHEMA IF EXISTS %s CASCADE;\n' "$(sql_quote_ident "$schema")"
    fi
  done
}

schema_reset_sql() {
  db_key="$1"
  pre_file="${2:-}"
  target_db="$(db_field "$db_key" target_db)"
  objects="$(target_reset_objects "$target_db" "$pre_file")"
  if [ -n "$objects" ]; then
    if [ "${ALLOW_SCHEMA_RESET:-false}" != "true" ]; then
      {
        echo "REFUSED: target schema public is not empty or target dump schemas already exist. Set options.allow_schema_reset=true for forward schema reset."
        printf '%s\n' "$objects" | sed 's/^/would_drop=/'
      } >&2
      return 1
    fi
    schema_drop_sql "$pre_file"
    cat <<'SQL'
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO public;
SQL
    return 0
  fi

  cat <<'SQL'
CREATE SCHEMA IF NOT EXISTS public;
GRANT ALL ON SCHEMA public TO public;
SQL
}

preflight_db() {
  db_key="$1"
  source_db="$(db_field "$db_key" source_db)"
  target_db="$(db_field "$db_key" target_db)"
  subscription="$(db_field "$db_key" subscription)"
  exclude_schemas="$(db_array_json "$db_key" exclude_schemas)"
  exclude_tables="$(db_array_json "$db_key" exclude_tables)"

  echo "== PREFLIGHT $db_key =="
  require_target_login_roles_configured || return 1
  echo "-- source settings"
  source_auth_psql "$source_db" -Atc "select 'server_version=' || current_setting('server_version'); select 'wal_level=' || current_setting('wal_level'); select 'max_replication_slots=' || current_setting('max_replication_slots'); select 'max_wal_senders=' || current_setting('max_wal_senders'); select 'max_slot_wal_keep_size=' || current_setting('max_slot_wal_keep_size');"
  echo "-- slot headroom"
  source_auth_psql "$source_db" -Atc "with s as (select count(*) used from pg_replication_slots) select 'replication_slots_used=' || used from s; select 'replication_slot_name=' || slot_name || ',active=' || active from pg_replication_slots order by slot_name;"
  echo "-- leftover publication / slot check"
  source_psql "$source_db" -Atc "select 'publication=' || pubname from pg_publication where pubname = '$(db_field "$db_key" publication)'; select 'slot=' || slot_name || ',active=' || active from pg_replication_slots where slot_name = '$subscription';"

  echo "-- replica identity audit"
  missing="$(source_psql "$source_db" -At -v exclude_schemas="$exclude_schemas" -v exclude_tables="$exclude_tables" <<'SQL'
WITH excluded_schemas AS (
  SELECT jsonb_array_elements_text(:'exclude_schemas'::jsonb) AS nspname
),
excluded_tables AS (
  SELECT jsonb_array_elements_text(:'exclude_tables'::jsonb) AS table_fqname
)
SELECT n.nspname || '.' || c.relname
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname !~ '^pg_toast'
  AND n.nspname !~ '^pg_temp_'
  AND n.nspname !~ '^pg_toast_temp_'
  AND NOT EXISTS (
    SELECT 1
    FROM excluded_schemas e
    WHERE e.nspname = n.nspname
  )
  AND NOT EXISTS (
    SELECT 1
    FROM excluded_tables t
    WHERE t.table_fqname = n.nspname || '.' || c.relname
  )
  AND NOT EXISTS (
    SELECT 1
    FROM pg_depend d
    JOIN pg_extension e ON e.oid = d.refobjid
    WHERE d.objid = c.oid
      AND d.deptype = 'e'
  )
  AND c.relreplident = 'd'
  AND NOT EXISTS (
    SELECT 1
    FROM pg_index i
    WHERE i.indrelid = c.oid
      AND i.indisprimary
  )
ORDER BY 1;
SQL
)"
  if [ -n "$missing" ]; then
    printf '%s\n' "$missing" | sed 's/^/missing_replica_identity=/'
    if [ "$FAIL_ON_MISSING_REPLICA_IDENTITY" = "true" ]; then
      echo "REFUSED: tables missing replica identity"
      return 1
    fi
  else
    echo "missing_replica_identity=0"
  fi

  echo "-- target settings"
  target_psql "$target_db" -Atc "select 'server_version=' || current_setting('server_version'); select 'target_database=' || current_database();"
  echo "-- source size vs target headroom"
  source_size_bytes="$(source_psql "$source_db" -Atc "select pg_database_size(current_database());")"
  echo "source_size_bytes=$source_size_bytes"
  echo "target_disk_gb=$TARGET_DISK_GB"
  echo "target_autoresize_limit_gb=$TARGET_AUTORESIZE_LIMIT_GB"
  if [ "$TARGET_AUTORESIZE_LIMIT_GB" != "0" ]; then
    headroom_bytes=$((TARGET_AUTORESIZE_LIMIT_GB * 1024 * 1024 * 1024))
    if [ "$source_size_bytes" -gt "$headroom_bytes" ]; then
      echo "REFUSED: source database is larger than target autoresize limit"
      return 1
    fi
  fi

  echo "-- collation comparison"
  src_coll="$(source_psql "$source_db" -Atc "select datcollate || '/' || coalesce(datcollversion, '') from pg_database where datname=current_database();")"
  tgt_coll="$(target_psql "$target_db" -Atc "select datcollate || '/' || coalesce(datcollversion, '') from pg_database where datname=current_database();")"
  echo "source_collation=$src_coll"
  echo "target_collation=$tgt_coll"
  if [ "$src_coll" != "$tgt_coll" ]; then
    echo "collation_differs=true"
  else
    echo "collation_differs=false"
  fi
}

publish_db() {
  db_key="$1"
  source_db="$(db_field "$db_key" source_db)"
  publication="$(db_field "$db_key" publication)"
  exclude_schemas="$(db_array_json "$db_key" exclude_schemas)"
  exclude_tables="$(db_array_json "$db_key" exclude_tables)"

  echo "== PUBLISH $db_key =="
  source_psql "$source_db" -v repl_user="$SOURCE_REPL_USER" -v repl_password="$SOURCE_REPL_PASSWORD" -v publication="$publication" -v exclude_schemas="$exclude_schemas" -v exclude_tables="$exclude_tables" <<'SQL'
SELECT CASE
  WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'repl_user')
  THEN format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'repl_user', :'repl_password')
  ELSE format('CREATE ROLE %I WITH LOGIN PASSWORD %L', :'repl_user', :'repl_password')
END \gexec
SELECT CASE
  WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rds_replication')
  THEN format('GRANT rds_replication TO %I', :'repl_user')
  ELSE format('ALTER ROLE %I WITH REPLICATION', :'repl_user')
END \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), :'repl_user') \gexec
SELECT format('ALTER ROLE %I SET statement_timeout = 0', :'repl_user') \gexec
SELECT format('ALTER ROLE %I SET lock_timeout = 0', :'repl_user') \gexec
SELECT format('ALTER ROLE %I SET idle_in_transaction_session_timeout = 0', :'repl_user') \gexec
SELECT format('GRANT USAGE ON SCHEMA %I TO %I', nspname, :'repl_user')
FROM pg_namespace
WHERE nspname NOT IN ('pg_catalog','information_schema')
  AND nspname !~ '^pg_toast'
  AND nspname !~ '^pg_temp_'
  AND nspname !~ '^pg_toast_temp_'
ORDER BY nspname \gexec
SELECT format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO %I', nspname, :'repl_user')
FROM pg_namespace
WHERE nspname NOT IN ('pg_catalog','information_schema')
  AND nspname !~ '^pg_toast'
  AND nspname !~ '^pg_temp_'
  AND nspname !~ '^pg_toast_temp_'
ORDER BY nspname \gexec
SELECT format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT ON TABLES TO %I', nspname, :'repl_user')
FROM pg_namespace
WHERE nspname NOT IN ('pg_catalog','information_schema')
  AND nspname !~ '^pg_toast'
  AND nspname !~ '^pg_temp_'
  AND nspname !~ '^pg_toast_temp_'
ORDER BY nspname \gexec
WITH excluded_schemas AS (
  SELECT jsonb_array_elements_text(:'exclude_schemas'::jsonb) AS nspname
),
excluded_tables AS (
  SELECT jsonb_array_elements_text(:'exclude_tables'::jsonb) AS table_fqname
),
publication_tables AS (
  SELECT n.nspname, c.relname
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname NOT IN ('pg_catalog','information_schema')
    AND n.nspname !~ '^pg_toast'
    AND n.nspname !~ '^pg_temp_'
    AND n.nspname !~ '^pg_toast_temp_'
    AND c.relkind = 'r'
    AND NOT EXISTS (
      SELECT 1
      FROM excluded_schemas e
      WHERE e.nspname = n.nspname
    )
    AND NOT EXISTS (
      SELECT 1
      FROM excluded_tables t
      WHERE t.table_fqname = n.nspname || '.' || c.relname
    )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_depend d
      JOIN pg_extension e ON e.oid = d.refobjid
      WHERE d.objid = c.oid
        AND d.deptype = 'e'
    )
),
publication_ddl AS (
  SELECT format(
    'DROP PUBLICATION IF EXISTS %I; CREATE PUBLICATION %I FOR TABLE %s WITH (publish = %L)',
    :'publication',
    :'publication',
    string_agg(format('%I.%I', nspname, relname), ', ' ORDER BY nspname, relname),
    'insert, update, delete, truncate'
  ) AS ddl
  FROM publication_tables
)
SELECT CASE
  WHEN ddl IS NULL THEN format('DO $$ BEGIN RAISE EXCEPTION %L; END $$', 'no publishable tables for publication ' || :'publication')
  ELSE ddl
END
FROM publication_ddl \gexec
SQL
  publication_sql_name="$(printf '%s' "$publication" | sed "s/'/''/g")"
  publication_table_count="$(source_psql "$source_db" -Atc "select count(*) from pg_publication_tables where pubname = '$publication_sql_name';" | sed -n '1p')"
  if [ "${publication_table_count:-0}" -le 0 ]; then
    echo "REFUSED: publication $publication has no tables after publish step" >&2
    return 1
  fi
  preflight_source_repl_timeouts "$db_key" || return 1
}

schema_db() {
  db_key="$1"
  source_db="$(db_field "$db_key" source_db)"
  target_db="$(db_field "$db_key" target_db)"
  pre="$WORK_DIR/$db_key-pre.sql"
  raw_pre="$WORK_DIR/$db_key-pre.raw.sql"

  echo "== SCHEMA $db_key =="
  if ! PGSSLMODE=require PGPASSWORD="$SOURCE_ADMIN_PASSWORD" pg_dump -h "$SOURCE_HOST" -p "$SOURCE_PORT" -U "$SOURCE_ADMIN_USER" -d "$source_db" --section=pre-data --no-owner --no-privileges > "$raw_pre"; then
    return 1
  fi
  if ! sanitize_pg_dump_sql "$db_key" < "$raw_pre" > "$pre"; then
    return 1
  fi
  ensure_target_login_roles "$db_key"
  schema_reset_sql "$db_key" "$pre" | target_psql "$target_db"
  target_psql "$target_db" -f "$pre"
}

load_db() {
  db_key="$1"
  source_db="$(db_field "$db_key" source_db)"
  target_db="$(db_field "$db_key" target_db)"
  publication="$(db_field "$db_key" publication)"
  subscription="$(db_field "$db_key" subscription)"

  echo "== LOAD $db_key =="
  conn="host=$SOURCE_HOST port=$SOURCE_PORT dbname=$source_db user=$SOURCE_REPL_USER password=$SOURCE_REPL_PASSWORD sslmode=require"
  sub_state="$(target_subscription_state "$db_key")"
  case "$sub_state" in
    true)
      echo "subscription_exists=true enabled=true"
      ;;
    false)
      echo "REFUSED: subscription exists but is disabled; use an explicit rebaseline-id to rebuild it" >&2
      return 1
      ;;
    MISSING)
      runtime_write_guard || return 1
      ;;
    *)
      echo "REFUSED: unexpected subscription state: $sub_state" >&2
      return 1
      ;;
  esac
  target_psql "$target_db" -v sub="$subscription" -v pub="$publication" -v conn="$conn" <<'SQL'
SELECT CASE
  WHEN EXISTS (SELECT 1 FROM pg_subscription WHERE subname = :'sub')
  THEN 'SELECT 1'
  ELSE format('CREATE SUBSCRIPTION %I CONNECTION %L PUBLICATION %I WITH (copy_data = true, create_slot = true, enabled = true, slot_name = %L)', :'sub', :'conn', :'pub', :'sub')
END \gexec
SQL
  if [ "${DEFER_SECONDARY_INDEXES:-true}" = "true" ]; then
    wait_tables_copy_finished_with_incremental_primary "$db_key"
  else
    wait_tables_ready "$db_key"
  fi
}

target_subscription_state() {
  db_key="$1"
  target_db="$(db_field "$db_key" target_db)"
  subscription="$(db_field "$db_key" subscription)"
  state="$(target_psql "$target_db" -Atc "select coalesce(subenabled::text, '') from pg_subscription where subname = '$subscription';")"
  if [ -z "$state" ]; then
    echo "MISSING"
  else
    printf '%s\n' "$state" | sed -n '1p'
  fi
}

attach_existing_db() {
  db_key="$1"
  source_db="$(db_field "$db_key" source_db)"
  target_db="$(db_field "$db_key" target_db)"
  publication="$(db_field "$db_key" publication)"
  subscription="$(db_field "$db_key" subscription)"

  echo "== ATTACH EXISTING $db_key =="
  if [ "${ATTACH_CONFIRM_EXISTING_BASELINE:-}" != "true" ] || [ "${ATTACH_CONFIRM_SOURCE_WRITES_FROZEN:-}" != "true" ]; then
    echo "REFUSED: attach-existing requires confirm_existing_baseline=true and confirm_source_writes_frozen=true" >&2
    return 1
  fi
  runtime_write_guard || return 1

  enabled_subscriptions="$(source_psql "$source_db" -Atc "select string_agg(subname, ',') from pg_subscription where subenabled;")"
  if [ -n "$enabled_subscriptions" ]; then
    echo "REFUSED: reverse source has an enabled subscription: $enabled_subscriptions; hold/disable forward replication first" >&2
    return 1
  fi

  sub_state="$(target_subscription_state "$db_key")"
  case "$sub_state" in
    true)
      echo "subscription_exists=true enabled=true attach_existing=idempotent"
      write_db_state "$db_key" "STEADY" "STEADY" "" 0 0
      return 0
      ;;
    false)
      echo "REFUSED: reverse subscription already exists but is disabled; inspect it before using resume" >&2
      return 1
      ;;
    MISSING)
      ;;
    *)
      echo "REFUSED: unexpected reverse subscription state: $sub_state" >&2
      return 1
      ;;
  esac

  if ! verify_parity_db "$db_key"; then
    echo "REFUSED: existing baseline parity verification failed" >&2
    return 1
  fi

  publish_db "$db_key" || return 1
  conn="host=$SOURCE_HOST port=$SOURCE_PORT dbname=$source_db user=$SOURCE_REPL_USER password=$SOURCE_REPL_PASSWORD sslmode=require"
  target_version_num="$(target_psql "$target_db" -Atc "show server_version_num;" | sed -n '1p')"
  case "$target_version_num" in
    ''|*[!0-9]*)
      echo "REFUSED: unable to determine target server_version_num" >&2
      return 1
      ;;
  esac

  if [ "$target_version_num" -ge 150000 ]; then
    target_psql "$target_db" -v sub="$subscription" -v pub="$publication" -v conn="$conn" <<'SQL'
SELECT format(
  'CREATE SUBSCRIPTION %I CONNECTION %L PUBLICATION %I WITH (copy_data = false, create_slot = true, enabled = true, slot_name = %L, origin = none)',
  :'sub', :'conn', :'pub', :'sub'
) \gexec
SQL
  else
    echo "WARNING: target PostgreSQL $target_version_num does not support subscription origin=none; forward replication must remain disabled" >&2
    target_psql "$target_db" -v sub="$subscription" -v pub="$publication" -v conn="$conn" <<'SQL'
SELECT format(
  'CREATE SUBSCRIPTION %I CONNECTION %L PUBLICATION %I WITH (copy_data = false, create_slot = true, enabled = true, slot_name = %L)',
  :'sub', :'conn', :'pub', :'sub'
) \gexec
SQL
  fi

  if [ "$(target_subscription_state "$db_key")" != "true" ]; then
    echo "REFUSED: reverse subscription was not created enabled" >&2
    return 1
  fi
  write_db_state "$db_key" "STEADY" "STEADY" "" 0 0
  echo "attach_existing=true copy_data=false subscription=$subscription"
}

cleanup_orphan_slot() {
  db_key="$1"
  source_db="$(db_field "$db_key" source_db)"
  target_db="$(db_field "$db_key" target_db)"
  subscription="$(db_field "$db_key" subscription)"
  sub_count="$(target_psql "$target_db" -Atc "select count(*) from pg_subscription where subname = '$subscription';" 2>/dev/null || echo 0)"
  if [ "$sub_count" = "0" ]; then
    cleanup_configured_slot "$db_key"
  fi
}

cleanup_configured_slot() {
  db_key="$1"
  source_db="$(db_field "$db_key" source_db)"
  subscription="$(db_field "$db_key" subscription)"
  echo "slot_cleanup db=$source_db slot=$subscription"
  source_psql "$source_db" -v slot="$subscription" -v source_db="$source_db" <<'SQL' || true
SELECT pg_drop_replication_slot(slot_name)
FROM pg_replication_slots
WHERE slot_name = :'slot'
  AND database = :'source_db'
  AND slot_type = 'logical'
  AND plugin = 'pgoutput'
  AND active = false;
SQL
}

drop_target_subscription() {
  db_key="$1"
  target_db="$(db_field "$db_key" target_db)"
  subscription="$(db_field "$db_key" subscription)"
  echo "subscription_cleanup db=$target_db subscription=$subscription"
  target_psql "$target_db" -v sub="$subscription" <<'SQL'
SELECT CASE
  WHEN EXISTS (SELECT 1 FROM pg_subscription WHERE subname = :'sub')
  THEN format('ALTER SUBSCRIPTION %I DISABLE', :'sub')
  ELSE 'SELECT 1'
END \gexec
SELECT CASE
  WHEN EXISTS (SELECT 1 FROM pg_subscription WHERE subname = :'sub')
  THEN format('ALTER SUBSCRIPTION %I SET (slot_name = NONE)', :'sub')
  ELSE 'SELECT 1'
END \gexec
SELECT CASE
  WHEN EXISTS (SELECT 1 FROM pg_subscription WHERE subname = :'sub')
  THEN format('DROP SUBSCRIPTION %I', :'sub')
  ELSE 'SELECT 1'
END \gexec
SQL
}

disable_target_subscription() {
  db_key="$1"
  target_db="$(db_field "$db_key" target_db)"
  subscription="$(db_field "$db_key" subscription)"
  echo "subscription_disable db=$target_db subscription=$subscription"
  target_psql "$target_db" -v sub="$subscription" <<'SQL'
SELECT CASE
  WHEN EXISTS (SELECT 1 FROM pg_subscription WHERE subname = :'sub' AND subenabled)
  THEN format('ALTER SUBSCRIPTION %I DISABLE', :'sub')
  ELSE 'SELECT 1'
END \gexec
SQL
}

enable_target_subscription() {
  db_key="$1"
  target_db="$(db_field "$db_key" target_db)"
  subscription="$(db_field "$db_key" subscription)"
  echo "subscription_enable db=$target_db subscription=$subscription"
  target_psql "$target_db" -v sub="$subscription" <<'SQL'
SELECT CASE
  WHEN EXISTS (SELECT 1 FROM pg_subscription WHERE subname = :'sub' AND NOT subenabled)
  THEN format('ALTER SUBSCRIPTION %I ENABLE', :'sub')
  ELSE 'SELECT 1'
END \gexec
SQL
}

write_rebaseline_state() {
  db_key="$1"
  value="$(build_db_state "$db_key" "REBASELINE" "NONE" "" 0 0 false)"
  state_patch "db-$db_key" "$value"
}

write_stopped_state() {
  db_key="$1"
  last="$(last_completed "$db_key")"
  value="$(build_db_state "$db_key" "STOPPED" "$last" "" 0 0 false)"
  state_patch "db-$db_key" "$value"
}

current_phase() {
  db_key="$1"
  current="$(state_get "db-$db_key")"
  if [ -z "$current" ]; then
    echo "NONE"
  else
    printf '%s' "$current" | jq -r '.phase // "NONE"'
  fi
}

require_phase() {
  db_key="$1"
  expected="$2"
  actual="$(current_phase "$db_key")"
  if [ "$actual" != "$expected" ]; then
    echo "REFUSED: $db_key must be in phase $expected; current phase=$actual" >&2
    return 1
  fi
}

require_steady() {
  db_key="$1"
  phase="$(current_phase "$db_key")"
  last="$(last_completed "$db_key")"
  if [ "$phase" != "STEADY" ] || [ "$last" != "STEADY" ]; then
    echo "REFUSED: $db_key must be STEADY before cutover hold; phase=$phase last_completed=$last" >&2
    return 1
  fi
}

write_cutover_held_state() {
  db_key="$1"
  value="$(build_db_state "$db_key" "CUTOVER_HELD" "STEADY" "" 0 0 false)"
  state_patch "db-$db_key" "$value"
}

write_cutover_finalized_state() {
  db_key="$1"
  value="$(build_db_state "$db_key" "CUTOVER_FINALIZED" "STEADY" "" 0 0 false)"
  state_patch "db-$db_key" "$value"
}

stop_db() {
  db_key="$1"
  runtime_write_guard || return 1
  echo "== STOP $db_key =="
  drop_target_subscription "$db_key"
  cleanup_configured_slot "$db_key"
  write_stopped_state "$db_key"
}

rebaseline_db() {
  db_key="$1"
  if [ -z "${REBASELINE_ID:-}" ]; then
    echo "REFUSED: rebaseline requires REBASELINE_ID" >&2
    return 1
  fi
  if [ "${ALLOW_SCHEMA_RESET:-false}" != "true" ]; then
    echo "REFUSED: rebaseline requires ALLOW_SCHEMA_RESET=true" >&2
    return 1
  fi
  runtime_write_guard || return 1
  echo "== REBASELINE $db_key id=$REBASELINE_ID =="
  drop_target_subscription "$db_key"
  cleanup_configured_slot "$db_key"
  write_rebaseline_state "$db_key"
}

maybe_rebaseline_db() {
  db_key="$1"
  [ -n "${REBASELINE_ID:-}" ] || return 0
  current="$(state_get "db-$db_key")"
  existing_id="$(printf '%s' "$current" | jq -r '.rebaseline_id // ""' 2>/dev/null || true)"
  if [ "$existing_id" = "$REBASELINE_ID" ]; then
    echo "SKIP $db_key REBASELINE already applied id=$REBASELINE_ID"
    return 0
  fi
  rebaseline_db "$db_key"
}

tables_progress() {
  db_key="$1"
  target_db="$(db_field "$db_key" target_db)"
  subscription="$(db_field "$db_key" subscription)"
  target_psql "$target_db" -Atc "select count(*) from pg_subscription_rel r join pg_subscription s on s.oid = r.srsubid where s.subname = '$subscription'; select count(*) from pg_subscription_rel r join pg_subscription s on s.oid = r.srsubid where s.subname = '$subscription' and r.srsubstate = 'r';"
}

tables_copy_progress() {
  db_key="$1"
  target_db="$(db_field "$db_key" target_db)"
  subscription="$(db_field "$db_key" subscription)"
  target_psql "$target_db" -Atc "select count(*) from pg_subscription_rel r join pg_subscription s on s.oid = r.srsubid where s.subname = '$subscription'; select count(*) from pg_subscription_rel r join pg_subscription s on s.oid = r.srsubid where s.subname = '$subscription' and r.srsubstate in ('f','s','r');"
}

subscription_copy_finished_relations() {
  db_key="$1"
  target_db="$(db_field "$db_key" target_db)"
  subscription="$(db_field "$db_key" subscription)"
  target_psql "$target_db" -Atc "select n.nspname || '.' || c.relname from pg_subscription_rel r join pg_subscription s on s.oid = r.srsubid join pg_class c on c.oid = r.srrelid join pg_namespace n on n.oid = c.relnamespace where s.subname = '$subscription' and r.srsubstate in ('f','s','r') order by 1;"
}

all_tables_ready() {
  db_key="$1"
  progress="$(tables_progress "$db_key")"
  total="$(printf '%s' "$progress" | sed -n '1p')"
  ready="$(printf '%s' "$progress" | sed -n '2p')"
  echo "tables_ready=$ready/$total"
  [ "${total:-0}" -gt 0 ] && [ "$total" = "$ready" ]
}

all_tables_copy_finished() {
  db_key="$1"
  progress="$(tables_copy_progress "$db_key")"
  total="$(printf '%s' "$progress" | sed -n '1p')"
  finished="$(printf '%s' "$progress" | sed -n '2p')"
  echo "tables_copy_finished=$finished/$total"
  [ "${total:-0}" -gt 0 ] && [ "$total" = "$finished" ]
}

wait_tables_ready() {
  db_key="$1"
  sleep_seconds="${LOAD_READY_SLEEP_SECONDS:-10}"
  timeout_seconds="${LOAD_READY_TIMEOUT_SECONDS:-600}"
  attempts=$(((timeout_seconds + sleep_seconds - 1) / sleep_seconds))
  [ "$attempts" -gt 0 ] || attempts=1
  i=1
  while [ "$i" -le "$attempts" ]; do
    if all_tables_ready "$db_key"; then
      return 0
    fi
    echo "waiting_for_subscription_tables attempt=$i/$attempts timeout_seconds=$timeout_seconds"
    sleep "$sleep_seconds"
    i=$((i + 1))
  done
  echo "REFUSED: subscription tables are not all ready within ${timeout_seconds}s"
  return 1
}

wait_tables_copy_finished() {
  db_key="$1"
  sleep_seconds="${LOAD_READY_SLEEP_SECONDS:-10}"
  timeout_seconds="${LOAD_READY_TIMEOUT_SECONDS:-600}"
  attempts=$(((timeout_seconds + sleep_seconds - 1) / sleep_seconds))
  [ "$attempts" -gt 0 ] || attempts=1
  i=1
  while [ "$i" -le "$attempts" ]; do
    if all_tables_copy_finished "$db_key"; then
      return 0
    fi
    echo "waiting_for_subscription_table_copies attempt=$i/$attempts timeout_seconds=$timeout_seconds"
    sleep "$sleep_seconds"
    i=$((i + 1))
  done
  echo "REFUSED: subscription table copies are not all finished within ${timeout_seconds}s"
  return 1
}

prepare_post_data_split_inputs() {
  db_key="$1"
  source_db="$(db_field "$db_key" source_db)"
  target_db="$(db_field "$db_key" target_db)"
  post="$WORK_DIR/$db_key-post.sql"
  target_relations="$WORK_DIR/$db_key-target-relations.txt"

  if [ ! -f "$post" ]; then
    PGSSLMODE=require PGPASSWORD="$SOURCE_ADMIN_PASSWORD" pg_dump -h "$SOURCE_HOST" -p "$SOURCE_PORT" -U "$SOURCE_ADMIN_USER" -d "$source_db" --section=post-data --no-owner --no-privileges | sanitize_pg_dump_sql "$db_key" > "$post"
  fi
  if [ ! -f "$target_relations" ]; then
    target_psql "$target_db" -Atc "select n.nspname || '.' || c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname not in ('pg_catalog','information_schema') and n.nspname !~ '^pg_temp_' and n.nspname !~ '^pg_toast_temp_' and c.relkind in ('r','p','i','I','S','v','m','f') order by 1;" > "$target_relations"
  fi
}

apply_copy_finished_primary_keys() {
  db_key="$1"
  post="$WORK_DIR/$db_key-post.sql"
  primary="$WORK_DIR/$db_key-primary-copy-finished.sql"
  secondary="$WORK_DIR/$db_key-secondary-copy-finished.sql"
  target_relations="$WORK_DIR/$db_key-target-relations.txt"
  finished_relations="$WORK_DIR/$db_key-copy-finished-relations.txt"
  finished_hash_file="$WORK_DIR/$db_key-copy-finished-relations.sha256"
  target_db="$(db_field "$db_key" target_db)"

  prepare_post_data_split_inputs "$db_key"
  subscription_copy_finished_relations "$db_key" > "$finished_relations"
  finished_hash="$(sha256sum "$finished_relations" | awk '{print $1}')"
  previous_hash="$(cat "$finished_hash_file" 2>/dev/null || true)"
  if [ "$finished_hash" = "$previous_hash" ]; then
    return 0
  fi
  : > "$primary"
  : > "$secondary"
  split_post_data_sql "$db_key" "$post" "$primary" "$secondary" "$target_relations" "$finished_relations"
  if [ -s "$primary" ]; then
    echo "applying_primary_keys_for_copy_finished_tables count=$(wc -l < "$finished_relations" | tr -d ' ')"
    target_psql "$target_db" -f "$primary"
  else
    echo "no_primary_keys_for_copy_finished_tables count=$(wc -l < "$finished_relations" | tr -d ' ')"
  fi
  printf '%s' "$finished_hash" > "$finished_hash_file"
}

wait_tables_copy_finished_with_incremental_primary() {
  db_key="$1"
  sleep_seconds="${LOAD_READY_SLEEP_SECONDS:-10}"
  timeout_seconds="${LOAD_READY_TIMEOUT_SECONDS:-600}"
  attempts=$(((timeout_seconds + sleep_seconds - 1) / sleep_seconds))
  [ "$attempts" -gt 0 ] || attempts=1
  i=1
  while [ "$i" -le "$attempts" ]; do
    apply_copy_finished_primary_keys "$db_key"
    if all_tables_copy_finished "$db_key"; then
      return 0
    fi
    echo "waiting_for_subscription_table_copies attempt=$i/$attempts timeout_seconds=$timeout_seconds"
    sleep "$sleep_seconds"
    i=$((i + 1))
  done
  echo "REFUSED: subscription table copies are not all finished within ${timeout_seconds}s"
  return 1
}

index_db() {
  db_key="$1"
  source_db="$(db_field "$db_key" source_db)"
  target_db="$(db_field "$db_key" target_db)"
  post="$WORK_DIR/$db_key-post.sql"
  primary="$WORK_DIR/$db_key-primary.sql"
  secondary="$WORK_DIR/$db_key-secondary.sql"
  target_relations="$WORK_DIR/$db_key-target-relations.txt"

  echo "== INDEX $db_key =="
  if [ "${DEFER_SECONDARY_INDEXES:-true}" = "true" ]; then
    if ! all_tables_copy_finished "$db_key"; then
      echo "REFUSED: subscription table copies are not all finished"
      return 1
    fi
  else
    if ! all_tables_ready "$db_key"; then
      echo "REFUSED: subscription tables are not all ready"
      return 1
    fi
  fi
  prepare_post_data_split_inputs "$db_key"
  : > "$primary"
  : > "$secondary"
  split_post_data_sql "$db_key" "$post" "$primary" "$secondary" "$target_relations"
  target_psql "$target_db" -f "$primary"
  wait_tables_ready "$db_key"
  target_psql "$target_db" -f "$secondary"
}

steady_db() {
  db_key="$1"
  target_db="$(db_field "$db_key" target_db)"
  subscription="$(db_field "$db_key" subscription)"
  echo "== STEADY $db_key =="
  target_psql "$target_db" -Atc "select 'subscription=' || subname || ',enabled=' || subenabled from pg_subscription where subname = '$subscription';"
}

sync_sequences_db() {
  db_key="$1"
  target_db="$(db_field "$db_key" target_db)"
  echo "== CUTOVER SYNC SEQUENCES $db_key =="
  runtime_write_guard || return 1
  require_replication_caught_up "$db_key" || return 1
  target_psql "$target_db" <<'SQL'
CREATE TEMP TABLE owned_sequences AS
SELECT
  seq_ns.nspname AS sequence_schema,
  seq.relname AS sequence_name,
  tbl_ns.nspname AS table_schema,
  tbl.relname AS table_name,
  att.attname AS column_name,
  att.atttypid::regtype::text AS column_type,
  quote_ident(seq_ns.nspname) || '.' || quote_ident(seq.relname) AS sequence_fqname
FROM pg_class seq
JOIN pg_namespace seq_ns ON seq_ns.oid = seq.relnamespace
JOIN pg_depend d ON d.objid = seq.oid
JOIN pg_class tbl ON tbl.oid = d.refobjid
JOIN pg_namespace tbl_ns ON tbl_ns.oid = tbl.relnamespace
JOIN pg_attribute att ON att.attrelid = tbl.oid AND att.attnum = d.refobjsubid
WHERE seq.relkind = 'S'
  AND d.deptype IN ('a', 'i')
  AND tbl_ns.nspname NOT IN ('pg_catalog', 'information_schema')
  AND tbl_ns.nspname !~ '^pg_temp_'
  AND tbl_ns.nspname !~ '^pg_toast_temp_';

SELECT format(
  'sequence_skip_non_integer=%I.%I table=%I.%I column=%I type=%s',
  sequence_schema,
  sequence_name,
  table_schema,
  table_name,
  column_name,
  column_type
)
FROM owned_sequences
WHERE column_type NOT IN ('smallint', 'integer', 'bigint')
ORDER BY sequence_schema, sequence_name;

SELECT format(
  'sequence_sync=%I.%I table=%I.%I column=%I',
  sequence_schema,
  sequence_name,
  table_schema,
  table_name,
  column_name
)
FROM owned_sequences
WHERE column_type IN ('smallint', 'integer', 'bigint')
ORDER BY sequence_schema, sequence_name;

SELECT format(
  'SELECT setval(%L, GREATEST(COALESCE((SELECT max(%I) FROM %I.%I), 1), 1), (SELECT max(%I) FROM %I.%I) IS NOT NULL);',
  sequence_fqname,
  column_name,
  table_schema,
  table_name,
  column_name,
  table_schema,
  table_name
)
FROM owned_sequences
WHERE column_type IN ('smallint', 'integer', 'bigint')
ORDER BY sequence_schema, sequence_name
\gexec
SQL
}

cutover_db() {
  db_key="$1"
  cutover_hold_db "$db_key"
}

cutover_hold_db() {
  db_key="$1"
  echo "== CUTOVER HOLD $db_key =="
  require_steady "$db_key" || return 1
  match_grants_db "$db_key" || return 1
  sync_sequences_db "$db_key" || return 1
  disable_target_subscription "$db_key"
  write_cutover_held_state "$db_key"
}

resume_db() {
  db_key="$1"
  echo "== RESUME $db_key =="
  runtime_write_guard || return 1
  require_phase "$db_key" "CUTOVER_HELD" || return 1
  if [ "${RESUME_CONFIRM_NO_TARGET_WRITES:-}" != "true" ]; then
    echo "REFUSED: resume requires RESUME_CONFIRM_NO_TARGET_WRITES=true because target writes during hold can diverge from source" >&2
    return 1
  fi
  sub_state="$(target_subscription_state "$db_key")"
  if [ "$sub_state" != "false" ]; then
    echo "REFUSED: resume requires an existing disabled subscription; state=$sub_state" >&2
    return 1
  fi
  enable_target_subscription "$db_key"
  wait_tables_ready "$db_key"
  write_db_state "$db_key" "STEADY" "STEADY" "" 0 0 false
}

finalize_cutover_db() {
  db_key="$1"
  echo "== FINALIZE CUTOVER $db_key =="
  runtime_write_guard || return 1
  require_phase "$db_key" "CUTOVER_HELD" || return 1
  drop_target_subscription "$db_key"
  cleanup_configured_slot "$db_key"
  write_cutover_finalized_state "$db_key"
}

is_zero_lag_value() {
  value="$1"
  case "$value" in
    "" | *[!0-9]*)
      return 1
      ;;
    0)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

require_subscription_enabled() {
  db_key="$1"
  state="$(target_subscription_state "$db_key")"
  if [ "$state" != "true" ]; then
    echo "REFUSED: subscription is not enabled; state=$state" >&2
    return 1
  fi
}

replication_lag_bytes() {
  db_key="$1"
  source_db="$(db_field "$db_key" source_db)"
  subscription="$(db_field "$db_key" subscription)"
  source_psql "$source_db" -Atc "select coalesce(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)::text, '') from pg_replication_slots where slot_name = '$subscription' and database = '$source_db' and slot_type = 'logical';" | sed -n '1p'
}

require_replication_caught_up() {
  db_key="$1"
  require_subscription_enabled "$db_key" || return 1
  if ! all_tables_ready "$db_key"; then
    echo "REFUSED: subscription tables are not all ready" >&2
    return 1
  fi
  lag_bytes="$(replication_lag_bytes "$db_key")"
  if ! is_zero_lag_value "$lag_bytes"; then
    echo "REFUSED: replication lag is non-zero or unknown; lag_bytes=${lag_bytes:-unknown}" >&2
    return 1
  fi
}

guard_phase_transition() {
  db_key="$1"
  phase="$2"
  case "$phase" in
    PREFLIGHT)
      return 0
      ;;
    PUBLISH | SCHEMA | LOAD)
      runtime_write_guard || return 1
      ;;
    INDEX)
      if [ "${DEFER_SECONDARY_INDEXES:-true}" = "true" ]; then
        if ! all_tables_copy_finished "$db_key"; then
          echo "REFUSED: subscription table copies are not all finished" >&2
          return 1
        fi
        return 0
      fi
      if ! all_tables_ready "$db_key"; then
        echo "REFUSED: subscription tables are not all ready" >&2
        return 1
      fi
      ;;
    STEADY)
      require_subscription_enabled "$db_key"
      if ! all_tables_ready "$db_key"; then
        echo "REFUSED: subscription tables are not all ready" >&2
        return 1
      fi
      ;;
    *)
      echo "unknown phase $phase" >&2
      return 1
      ;;
  esac
}

run_phase() {
  db_key="$1"
  phase="$2"
  case "$phase" in
    PREFLIGHT) preflight_db "$db_key" ;;
    PUBLISH) publish_db "$db_key" ;;
    SCHEMA) schema_db "$db_key" ;;
    LOAD) load_db "$db_key" ;;
    INDEX) index_db "$db_key" ;;
    STEADY) steady_db "$db_key" ;;
    *) echo "unknown phase $phase"; return 1 ;;
  esac
}

run_driver_db() {
  db_key="$1"
  if [ -n "${REBASELINE_ID:-}" ]; then
    last_before_rebaseline="$(last_completed "$db_key")"
    stdout_file="$WORK_DIR/$db_key-REBASELINE-stdout.log"
    stderr_file="$WORK_DIR/$db_key-REBASELINE-stderr.log"
    if maybe_rebaseline_db "$db_key" >"$stdout_file" 2>"$stderr_file"; then
      cat "$stdout_file"
    else
      cat "$stdout_file"
      cat "$stderr_file" >&2
      phase_error="$(sanitize_error <"$stderr_file")"
      if [ -z "$phase_error" ]; then
        phase_error="rebaseline failed"
      fi
      write_db_state "$db_key" "BLOCKED" "$last_before_rebaseline" "$phase_error" 0 0
      return 1
    fi
  fi
  last="$(last_completed "$db_key")"
  last_idx="$(phase_index "$last")"
  failed=0
  for phase in $PHASES; do
    phase_idx="$(phase_index "$phase")"
    if [ "$phase_idx" -le "$last_idx" ]; then
      echo "SKIP $db_key $phase already completed"
      continue
    fi
    guard_stdout_file="$WORK_DIR/$db_key-$phase-guard-stdout.log"
    guard_stderr_file="$WORK_DIR/$db_key-$phase-guard-stderr.log"
    if ! guard_phase_transition "$db_key" "$phase" >"$guard_stdout_file" 2>"$guard_stderr_file"; then
      cat "$guard_stdout_file"
      cat "$guard_stderr_file" >&2
      phase_error="$(sanitize_error <"$guard_stderr_file")"
      if [ -z "$phase_error" ]; then
        phase_error="transition guard refused $phase"
      fi
      write_db_state "$db_key" "BLOCKED" "$last" "$phase_error" 0 0
      return 1
    fi
    write_db_state "$db_key" "$phase" "$last" "" 0 0
    stdout_file="$WORK_DIR/$db_key-$phase-stdout.log"
    stderr_file="$WORK_DIR/$db_key-$phase-stderr.log"
    if run_phase "$db_key" "$phase" >"$stdout_file" 2>"$stderr_file"; then
      cat "$stdout_file"
      progress="$(tables_progress "$db_key" 2>/dev/null || printf '0\n0\n')"
      total="$(printf '%s' "$progress" | sed -n '1p')"
      ready="$(printf '%s' "$progress" | sed -n '2p')"
      write_db_state "$db_key" "$phase" "$phase" "" "${total:-0}" "${ready:-0}" true
      last="$phase"
      last_idx="$phase_idx"
    else
      cat "$stdout_file"
      cat "$stderr_file" >&2
      phase_error="$(sanitize_error <"$stderr_file")"
      if [ -z "$phase_error" ]; then
        phase_error="phase failed"
      fi
      failed=1
      if [ "$phase" = "PREFLIGHT" ]; then
        write_db_state "$db_key" "BLOCKED" "$last" "$phase_error" 0 0
      else
        write_db_state "$db_key" "$phase" "$last" "$phase_error" 0 0
      fi
      if [ "$phase" = "LOAD" ]; then
        cleanup_orphan_slot "$db_key"
      fi
      break
    fi
  done
  return "$failed"
}

preflight_error_summary() {
  stdout_file="$1"
  stderr_file="$2"
  summary="$(cat "$stdout_file" "$stderr_file" | grep -E 'REFUSED|missing_replica_identity|FATAL|ERROR|Error|failed|cannot' || true)"
  if [ -z "$summary" ]; then
    cat "$stdout_file" "$stderr_file"
  else
    printf '%s\n' "$summary"
  fi
}

run_preflight_only_db() {
  db_key="$1"
  last="$(last_completed "$db_key")"
  failed=0
  write_db_state "$db_key" "PREFLIGHT" "$last" "" 0 0
  stdout_file="$WORK_DIR/$db_key-PREFLIGHT-stdout.log"
  stderr_file="$WORK_DIR/$db_key-PREFLIGHT-stderr.log"
  if preflight_db "$db_key" >"$stdout_file" 2>"$stderr_file"; then
    cat "$stdout_file"
    write_db_state "$db_key" "PREFLIGHT" "PREFLIGHT" "" 0 0 true
  else
    cat "$stdout_file"
    cat "$stderr_file" >&2
    phase_error="$(preflight_error_summary "$stdout_file" "$stderr_file" | sanitize_error)"
    if [ -z "$phase_error" ]; then
      phase_error="preflight failed"
    fi
    write_db_state "$db_key" "BLOCKED" "$last" "$phase_error" 0 0
    failed=1
  fi
  return "$failed"
}

run_preflight_only() {
  failed=0
  for db_key in $(db_keys); do
    run_preflight_only_db "$db_key" || failed=1
  done
  slack_update || true
  return "$failed"
}

verify_parity_db() {
  db_key="$1"
  source_db="$(db_field "$db_key" source_db)"
  target_db="$(db_field "$db_key" target_db)"
  exclude_schemas="$(db_array_json "$db_key" exclude_schemas)"
  exclude_tables="$(db_array_json "$db_key" exclude_tables)"
  echo "== VERIFY PARITY $db_key =="
  tables="$(source_psql "$source_db" -At -v exclude_schemas="$exclude_schemas" -v exclude_tables="$exclude_tables" <<'SQL'
WITH excluded_schemas AS (
  SELECT jsonb_array_elements_text(:'exclude_schemas'::jsonb) AS nspname
),
excluded_tables AS (
  SELECT jsonb_array_elements_text(:'exclude_tables'::jsonb) AS table_fqname
)
SELECT quote_ident(n.nspname) || '.' || quote_ident(c.relname)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN excluded_schemas es ON es.nspname = n.nspname
LEFT JOIN excluded_tables et ON et.table_fqname = n.nspname || '.' || c.relname
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname !~ '^pg_temp_'
  AND n.nspname !~ '^pg_toast_temp_'
  AND es.nspname IS NULL
  AND et.table_fqname IS NULL
ORDER BY 1;
SQL
)"
  parity_total=0
  parity_mismatch=""
  parity_tables_file="$WORK_DIR/$db_key-parity-tables.txt"
  printf '%s\n' "$tables" > "$parity_tables_file"
  while IFS= read -r tbl; do
    [ -n "$tbl" ] || continue
    parity_total=$((parity_total + 1))
    src="$(source_psql "$source_db" -Atc "select count(*) from $tbl;")"
    tgt="$(target_psql "$target_db" -Atc "select count(*) from $tbl;")"
    delta=$((src - tgt))
    printf '%s source=%s target=%s delta=%s\n' "$tbl" "$src" "$tgt" "$delta"
    if [ "$delta" -ne 0 ] && [ -z "$parity_mismatch" ]; then
      parity_mismatch="$tbl source=$src target=$tgt"
    fi
  done < "$parity_tables_file"

  if [ -n "$parity_mismatch" ]; then
    state_patch last_parity "MISMATCH: $parity_mismatch"
    state_patch last_parity_at "$(current_timestamp)"
    return 1
  fi

  state_patch last_parity "$parity_total/$parity_total tables match"
  state_patch last_parity_at "$(current_timestamp)"
}

verify_lag_db() {
  db_key="$1"
  source_db="$(db_field "$db_key" source_db)"
  target_db="$(db_field "$db_key" target_db)"
  subscription="$(db_field "$db_key" subscription)"
  echo "== VERIFY LAG $db_key =="
  lag_slot_line="$(source_psql "$source_db" -Atc "select 'slot=' || slot_name || ',active=' || active || ',restart_lsn=' || restart_lsn || ',confirmed_flush_lsn=' || confirmed_flush_lsn || ',retained_wal_bytes=' || pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) || ',lag_bytes=' || pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) from pg_replication_slots where slot_name = '$subscription' and database = '$source_db' and slot_type = 'logical';")"
  printf '%s\n' "$lag_slot_line"
  lag_target_lines="$(target_psql "$target_db" -Atc "select 'subscription=' || subname || ',enabled=' || subenabled from pg_subscription where subname = '$subscription'; select 'received_lsn=' || received_lsn || ',latest_end_lsn=' || latest_end_lsn from pg_stat_subscription where subname = '$subscription';")"
  printf '%s\n' "$lag_target_lines"

  retained_wal_bytes="$(printf '%s' "$lag_slot_line" | sed -n 's/.*retained_wal_bytes=\([^,]*\).*/\1/p')"
  lag_bytes="$(printf '%s' "$lag_slot_line" | sed -n 's/.*lag_bytes=\([^,]*\).*/\1/p' | tail -n 1)"
  state_patch last_lag "slot $subscription retained=${retained_wal_bytes:-unknown}B lag=${lag_bytes:-unknown}B"
  state_patch last_lag_at "$(current_timestamp)"
}

subscription_states_db() {
  db_key="$1"
  target_db="$(db_field "$db_key" target_db)"
  subscription="$(db_field "$db_key" subscription)"
  echo "== SUBSCRIPTION REL STATES $db_key =="
  target_psql "$target_db" -Atc "select n.nspname || '.' || c.relname || '=' || r.srsubstate::text from pg_subscription_rel r join pg_subscription s on s.oid = r.srsubid join pg_class c on c.oid = r.srrelid join pg_namespace n on n.oid = c.relnamespace where s.subname = '$subscription' order by 1;"
}

slack_api_post() {
  slack_api_method="$1"
  slack_api_payload="$2"
  slack_api_error=""
  slack_api_response="$(curl -fsS -H "Authorization: Bearer $slack_token" -H "Content-Type: application/json" --data "$slack_api_payload" "https://slack.com/api/$slack_api_method")" || {
    slack_api_error="curl_error"
    echo "slack $slack_api_method failed: curl_error" >&2
    return 1
  }
  slack_api_ok="$(printf '%s' "$slack_api_response" | jq -r '.ok // false')"
  if [ "$slack_api_ok" != "true" ]; then
    slack_api_error="$(printf '%s' "$slack_api_response" | jq -r '.error // "unknown_error"')"
    echo "slack $slack_api_method failed: $slack_api_error" >&2
    return 1
  fi
  printf '%s' "$slack_api_response"
}

slack_api_history() {
  slack_history_ts="$1"
  slack_api_error=""
  slack_api_response="$(curl -fsS -H "Authorization: Bearer $slack_token" -G --data-urlencode "channel=$SLACK_CHANNEL_ID" --data-urlencode "ts=$slack_history_ts" https://slack.com/api/conversations.history)" || {
    slack_api_error="curl_error"
    echo "slack conversations.history failed: curl_error" >&2
    return 1
  }
  slack_api_ok="$(printf '%s' "$slack_api_response" | jq -r '.ok // false')"
  if [ "$slack_api_ok" != "true" ]; then
    slack_api_error="$(printf '%s' "$slack_api_response" | jq -r '.error // "unknown_error"')"
    echo "slack conversations.history failed: $slack_api_error" >&2
    return 1
  fi
  printf '%s' "$slack_api_response"
}

slack_post_message() {
  slack_post_text="$1"
  slack_post_response="$(slack_api_post chat.postMessage "$(jq -n --arg channel "$SLACK_CHANNEL_ID" --arg text "$slack_post_text" '{channel:$channel,text:$text}')")" || return 1
  slack_new_ts="$(printf '%s' "$slack_post_response" | jq -r '.ts // ""')"
  if [ -z "$slack_new_ts" ] || [ "$slack_new_ts" = "null" ]; then
    echo "slack chat.postMessage failed: missing_ts" >&2
    return 1
  fi
  state_patch slack_message_ts "$slack_new_ts"
  echo "slack chat.postMessage posted ts=$slack_new_ts" >&2
}

slack_update() {
  [ -n "$SLACK_CHANNEL_ID" ] || return 0
  slack_token="${SLACK_TOKEN:-${SLACK_BOT_TOKEN:-}}"
  [ -n "$slack_token" ] || return 0

  ensure_state
  slack_message_ts="$(state_get slack_message_ts)"
  slack_tracker_text="$(status_text)"
  if [ -z "$slack_message_ts" ]; then
    slack_post_message "$slack_tracker_text" || true
    return 0
  fi

  slack_history_response="$(slack_api_history "$slack_message_ts")" || return 0
  slack_live_count="$(printf '%s' "$slack_history_response" | jq -r '.messages | length')"
  if [ "${slack_live_count:-0}" -eq 0 ]; then
    echo "slack conversations.history found no message for ts=$slack_message_ts; posting replacement" >&2
    state_patch slack_message_ts ""
    slack_post_message "$slack_tracker_text" || true
    return 0
  fi

  slack_live_text="$(printf '%s' "$slack_history_response" | jq -r '.messages[0].text // ""')"
  slack_merged_text="$slack_tracker_text"
  if [ -n "$slack_live_text" ] && printf '%s' "$slack_live_text" | grep -q '^Human notes:'; then
    slack_notes="$(printf '%s' "$slack_live_text" | sed -n '/^Human notes:/,$p')"
    slack_merged_text="$slack_tracker_text

$slack_notes"
  fi
  if slack_api_post chat.update "$(jq -n --arg channel "$SLACK_CHANNEL_ID" --arg ts "$slack_message_ts" --arg text "$slack_merged_text" '{channel:$channel,ts:$ts,text:$text}')" >/dev/null; then
    echo "slack chat.update updated ts=$slack_message_ts" >&2
    return 0
  fi

  if [ "${slack_api_error:-}" = "message_not_found" ]; then
    echo "slack chat.update message_not_found for ts=$slack_message_ts; posting replacement" >&2
    state_patch slack_message_ts ""
    slack_post_message "$slack_tracker_text" || true
  fi
}

subscription_state_label() {
  case "$1" in
    i) printf 'init' ;;
    d) printf 'data_copy' ;;
    f) printf 'finished_copy' ;;
    s) printf 'sync_done' ;;
    r) printf 'ready' ;;
    *) printf 'other' ;;
  esac
}

subscription_state_summary() {
  db_key="$1"
  target_db="$(db_field "$db_key" target_db)"
  subscription="$(db_field "$db_key" subscription)"

  enabled="$(target_psql "$target_db" -Atc "select 'enabled=' || subenabled from pg_subscription where subname = '$subscription';" 2>/dev/null || true)"
  if [ -z "$enabled" ]; then
    printf ' subscription=%s missing' "$subscription"
    return 0
  fi

  states="$(target_psql "$target_db" -Atc "select r.srsubstate::text || '=' || count(*) from pg_subscription_rel r join pg_subscription s on s.oid = r.srsubid where s.subname = '$subscription' group by r.srsubstate order by r.srsubstate;" 2>/dev/null || true)"
  state_summary=""
  for state_key in r d f i s; do
    count="$(printf '%s\n' "$states" | sed -n "s/^$state_key=//p")"
    [ -n "$count" ] || count=0
    label="$(subscription_state_label "$state_key")"
    state_summary="$state_summary $label=$count"
  done
  other_count="$(printf '%s\n' "$states" | awk -F= '$1 !~ /^(r|d|f|i|s)$/ && $1 != "" { sum += $2 } END { print sum + 0 }')"
  if [ "$other_count" != "0" ]; then
    state_summary="$state_summary other=$other_count"
  fi

  non_ready="$(target_psql "$target_db" -Atc "select n.nspname || '.' || c.relname || '=' || r.srsubstate::text from pg_subscription_rel r join pg_subscription s on s.oid = r.srsubid join pg_class c on c.oid = r.srrelid join pg_namespace n on n.oid = c.relnamespace where s.subname = '$subscription' and r.srsubstate <> 'r' order by 1 limit 5;" 2>/dev/null || true)"
  non_ready_inline=""
  if [ -n "$non_ready" ]; then
    non_ready_inline=" non_ready=$(printf '%s\n' "$non_ready" | paste -sd, -)"
  fi

  printf ' subscription=%s %s states%s%s' "$subscription" "$enabled" "$state_summary" "$non_ready_inline"
}

status_subscription_suffix() {
  db_key="$1"
  phase="$2"
  ready="$3"
  total="$4"

  case "$phase" in
    LOAD | INDEX)
      subscription_state_summary "$db_key"
      ;;
    STEADY)
      if [ "${ready:-0}" != "${total:-0}" ]; then
        subscription_state_summary "$db_key"
      fi
      ;;
  esac
}

status_text() {
  now_epoch="$(current_epoch)"
  status_dir="$WORK_DIR/status-$$"
  mkdir -p "$status_dir"
  blocked_file="$status_dir/blocked"
  active_file="$status_dir/active"
  complete_file="$status_dir/complete"
  not_started_file="$status_dir/not-started"
  : > "$blocked_file"
  : > "$active_file"
  : > "$complete_file"
  : > "$not_started_file"

  for db_key in $(db_keys); do
    state="$(state_get "db-$db_key")"
    if [ -z "$state" ]; then
      echo "$db_key" >> "$not_started_file"
      continue
    fi

    phase="$(printf '%s' "$state" | jq -r '.phase')"
    last="$(printf '%s' "$state" | jq -r '.last_completed_phase')"
    ready="$(printf '%s' "$state" | jq -r '.tables_ready')"
    total="$(printf '%s' "$state" | jq -r '.tables_total')"
    err="$(printf '%s' "$state" | jq -r '.last_error')"
    started_epoch="$(printf '%s' "$state" | jq -r '.phase_started_epoch // ""')"
    elapsed=""
    if [ -n "$started_epoch" ] && [ "$started_epoch" != "null" ]; then
      elapsed_seconds=$((now_epoch - started_epoch))
      if [ "$elapsed_seconds" -lt 0 ]; then
        elapsed_seconds=0
      fi
      elapsed=" elapsed=${elapsed_seconds}s"
    fi

    case "$phase:$last" in
      BLOCKED:*)
        printf '%s: %s\n' "$db_key" "$(status_error_summary "$err")" >> "$blocked_file"
        ;;
      PREFLIGHT:PREFLIGHT)
        echo "$db_key" >> "$complete_file"
        ;;
      STEADY:STEADY)
        suffix="$(status_subscription_suffix "$db_key" "$phase" "$ready" "$total" 2>/dev/null || true)"
        echo "$db_key: STEADY tables=$ready/$total$suffix" >> "$active_file"
        ;;
      CUTOVER_HELD:*)
        echo "$db_key: CUTOVER_HELD tables=$ready/$total subscription=disabled" >> "$active_file"
        ;;
      CUTOVER_FINALIZED:*)
        echo "$db_key: CUTOVER_FINALIZED tables=$ready/$total subscription=dropped" >> "$active_file"
        ;;
      *)
        suffix="$(status_subscription_suffix "$db_key" "$phase" "$ready" "$total" 2>/dev/null || true)"
        echo "$db_key: phase=$phase last=$last tables=$ready/$total$elapsed$suffix" >> "$active_file"
        ;;
    esac
  done

  {
    echo ":arrows_counterclockwise: *$STATE_CONFIGMAP - PostgreSQL logical replication*"
    echo ""
    status_print_section "Blocked" "$blocked_file"
    status_print_section "In progress / steady" "$active_file"
    status_print_section "Preflight complete" "$complete_file"
    status_print_section "Not started" "$not_started_file"

    last_parity="$(state_get last_parity)"
    last_parity_at="$(state_get last_parity_at)"
    if [ -n "$last_parity" ]; then
      if [ -n "$last_parity_at" ]; then
        echo "Last parity check: $last_parity at $last_parity_at"
      else
        echo "Last parity check: $last_parity"
      fi
    fi
    last_lag="$(state_get last_lag)"
    last_lag_at="$(state_get last_lag_at)"
    if [ -n "$last_lag" ]; then
      if [ -n "$last_lag_at" ]; then
        echo "WAL retention: $last_lag at $last_lag_at"
      else
        echo "WAL retention: $last_lag"
      fi
    fi
    echo "_Last updated: $(TZ=Asia/Kolkata date '+%d %b %Y, %H:%M IST')_"
  }
}

status_print_section() {
  title="$1"
  file="$2"
  [ -s "$file" ] || return 0
  echo "*$title*"
  echo '```'
  cat "$file"
  echo '```'
  echo ""
}

status_error_summary() {
  err="$1"
  missing_items="$(printf '%s' "$err" | tr ' ' '\n' | sed -n 's/^missing_replica_identity=//p')"
  if [ -n "$missing_items" ]; then
    missing_count="$(printf '%s\n' "$missing_items" | sed '/^$/d' | wc -l | tr -d ' ')"
    first_items="$(printf '%s\n' "$missing_items" | sed '/^$/d' | sed -n '1,3p' | awk 'NR == 1 { out = $0; next } { out = out ", " $0 } END { print out }')"
    if [ "$missing_count" -gt 3 ]; then
      more_count=$((missing_count - 3))
      printf 'replica identity missing: %s (+%s more)' "$first_items" "$more_count"
    else
      printf 'replica identity missing: %s' "$first_items"
    fi
    return 0
  fi

  if [ -n "$err" ]; then
    printf '%s' "$err"
  else
    printf 'blocked'
  fi
}

status_dump() {
  ensure_state
  kube_curl GET "$(state_path)" | jq '.data'
  slack_update
}

main() {
  need_tools
  mode="${ACTION_MODE_OVERRIDE:-${1:-driver}}"
  failed=0
  case "$mode" in
    driver)
      acquire_mutation_lock "$mode" || exit 1
      trap release_mutation_lock EXIT INT TERM
      for db_key in $(db_keys); do
        run_driver_db "$db_key" || failed=1
        slack_update
      done
      ;;
    preflight-only)
      require_no_mutation_lock || exit 1
      run_preflight_only || failed=1
      ;;
    discover-roles)
      require_no_mutation_lock || exit 1
      discover_roles || failed=1
      ;;
    match-grants)
      acquire_mutation_lock "$mode" || exit 1
      trap release_mutation_lock EXIT INT TERM
      for db_key in $(db_keys); do match_grants_db "$db_key" || failed=1; done
      slack_update || true
      ;;
    attach-existing)
      acquire_mutation_lock "$mode" || exit 1
      trap release_mutation_lock EXIT INT TERM
      for db_key in $(db_keys); do attach_existing_db "$db_key" || failed=1; done
      slack_update || true
      ;;
    match-grants-dryrun)
      require_no_mutation_lock || exit 1
      for db_key in $(db_keys); do match_grants_dryrun_db "$db_key" || failed=1; done
      ;;
    verify-parity)
      require_no_mutation_lock || exit 1
      for db_key in $(db_keys); do verify_parity_db "$db_key" || failed=1; done
      slack_update || true
      ;;
    verify-lag)
      for db_key in $(db_keys); do verify_lag_db "$db_key" || failed=1; done
      slack_update || true
      ;;
    stop-selected|stop-all)
      acquire_mutation_lock "$mode" || exit 1
      trap release_mutation_lock EXIT INT TERM
      for db_key in $(db_keys); do stop_db "$db_key" || failed=1; done
      slack_update || true
      ;;
    cutover)
      acquire_mutation_lock "$mode" || exit 1
      trap release_mutation_lock EXIT INT TERM
      for db_key in $(db_keys); do cutover_hold_db "$db_key" || failed=1; done
      slack_update || true
      ;;
    cutover-hold)
      acquire_mutation_lock "$mode" || exit 1
      trap release_mutation_lock EXIT INT TERM
      for db_key in $(db_keys); do cutover_hold_db "$db_key" || failed=1; done
      slack_update || true
      ;;
    resume)
      acquire_mutation_lock "$mode" || exit 1
      trap release_mutation_lock EXIT INT TERM
      for db_key in $(db_keys); do resume_db "$db_key" || failed=1; done
      slack_update || true
      ;;
    finalize-cutover)
      acquire_mutation_lock "$mode" || exit 1
      trap release_mutation_lock EXIT INT TERM
      for db_key in $(db_keys); do finalize_cutover_db "$db_key" || failed=1; done
      slack_update || true
      ;;
    subscription-states)
      for db_key in $(db_keys); do subscription_states_db "$db_key" || failed=1; done
      ;;
    poll|status)
      for db_key in $(db_keys); do
        progress="$(tables_progress "$db_key" 2>/dev/null || printf '0\n0\n')"
        total="$(printf '%s' "$progress" | sed -n '1p')"
        ready="$(printf '%s' "$progress" | sed -n '2p')"
        state="$(state_get "db-$db_key")"
        if [ -n "$state" ]; then
          phase="$(printf '%s' "$state" | jq -r '.phase')"
          last="$(printf '%s' "$state" | jq -r '.last_completed_phase')"
          err="$(printf '%s' "$state" | jq -r '.last_error')"
          write_db_state "$db_key" "$phase" "$last" "$err" "${total:-0}" "${ready:-0}"
        fi
      done
      status_dump
      ;;
    *)
      echo "unknown mode $mode"
      exit 2
      ;;
  esac
  exit "$failed"
}

if [ "${POSTGRES_REPLICATION_LIB_ONLY:-false}" != "true" ]; then
  main "$@"
fi

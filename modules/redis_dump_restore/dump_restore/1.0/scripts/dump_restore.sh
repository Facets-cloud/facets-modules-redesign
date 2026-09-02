#!/bin/sh
set -eu

SCRIPT_DIR="${REDIS_DUMP_RESTORE_SCRIPT_DIR:-/scripts}"
. "$SCRIPT_DIR/config.sh"

mode="${ACTION_MODE_OVERRIDE:-${1:-status}}"

redis_cli_bin() {
  if command -v redis-cli >/dev/null 2>&1; then
    printf 'redis-cli'
  elif command -v valkey-cli >/dev/null 2>&1; then
    printf 'valkey-cli'
  else
    return 1
  fi
}

need_tools() {
  redis_cli_bin >/dev/null 2>&1 || return 1
  if command -v jq >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
    return 0
  fi
  if command -v apk >/dev/null 2>&1; then
    apk add --no-cache jq curl coreutils >/dev/null
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update >/dev/null && apt-get install -y jq curl coreutils >/dev/null
  else
    return 0
  fi
}

redis_cli_base() {
  side="$1"
  db="$2"
  if [ "$side" = "source" ]; then
    host="$SOURCE_HOST"; port="$SOURCE_PORT"; token="${SOURCE_AUTH_TOKEN:-}"; tls="${SOURCE_TLS:-false}"
  else
    host="$TARGET_HOST"; port="$TARGET_PORT"; token="${TARGET_AUTH_TOKEN:-}"; tls="${TARGET_TLS:-false}"
  fi
  bin="$(redis_cli_bin 2>/dev/null || printf redis-cli)"
  cmd="$bin -h $host -p $port -n $db"
  [ "$tls" = "true" ] && cmd="$cmd --tls"
  [ -n "$token" ] && cmd="$cmd --no-auth-warning -a $token"
  printf '%s' "$cmd"
}

redis_cli() {
  side="$1"
  db="$2"
  shift 2
  bin="$(redis_cli_bin)"
  if [ "$side" = "source" ]; then
    host="$SOURCE_HOST"; port="$SOURCE_PORT"; token="${SOURCE_AUTH_TOKEN:-}"; tls="${SOURCE_TLS:-false}"
  else
    host="$TARGET_HOST"; port="$TARGET_PORT"; token="${TARGET_AUTH_TOKEN:-}"; tls="${TARGET_TLS:-false}"
  fi
  if [ "$tls" = "true" ] && [ -n "$token" ]; then
    "$bin" -h "$host" -p "$port" -n "$db" --tls --no-auth-warning -a "$token" "$@"
  elif [ "$tls" = "true" ]; then
    "$bin" -h "$host" -p "$port" -n "$db" --tls "$@"
  elif [ -n "$token" ]; then
    "$bin" -h "$host" -p "$port" -n "$db" --no-auth-warning -a "$token" "$@"
  else
    "$bin" -h "$host" -p "$port" -n "$db" "$@"
  fi
}

redis_cli_timed() {
  timeout_seconds="${REDIS_COMMAND_TIMEOUT_SECONDS:-15}"
  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_seconds" "$0" __redis_cli "$@"
  else
    redis_cli "$@"
  fi
}

if [ "${1:-}" = "__redis_cli" ]; then
  shift
  redis_cli "$@"
  exit $?
fi

kube_api_url() {
  [ -n "${KUBERNETES_SERVICE_HOST:-}" ] || return 1
  printf 'https://%s:%s' "$KUBERNETES_SERVICE_HOST" "${KUBERNETES_SERVICE_PORT_HTTPS:-443}"
}

state_path() {
  printf '/api/v1/namespaces/%s/configmaps/%s' "$NAMESPACE" "$STATE_CONFIGMAP"
}

kube_api_curl() {
  method="$1"; path="$2"; payload="${3:-}"
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
  body="$(jq -n --arg name "$STATE_CONFIGMAP" --arg namespace "$NAMESPACE" '{
    apiVersion:"v1",
    kind:"ConfigMap",
    metadata:{name:$name, namespace:$namespace, labels:{"app.kubernetes.io/name":"redis-dump-restore"}},
    data:{}
  }')"
  kube_api_curl POST "/api/v1/namespaces/$NAMESPACE/configmaps" "$body" >/dev/null
}

state_get() {
  key="$1"
  ensure_state || return 0
  kube_api_curl GET "$(state_path)" 2>/dev/null | jq -r --arg key "$key" '.data[$key] // ""' 2>/dev/null || true
}

state_set() {
  key="$1"; value="$2"
  ensure_state || return 0
  patch_payload="$(jq -n --arg key "$key" --arg value "$value" '{data:{($key):$value}}')"
  kube_api_curl PATCH "$(state_path)" "$patch_payload" >/dev/null
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

strip_cr() {
  tr -d '\r'
}

toml_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

toml_bool() {
  case "${1:-false}" in
    true|TRUE|True|1|yes|YES|Yes)
      printf 'true'
      ;;
    *)
      printf 'false'
      ;;
  esac
}

is_uint() {
  case "${1:-}" in
    ''|*[!0-9]*)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

write_dataset_state() {
  dataset="$1"; phase="$2"; last="$3"; err="${4:-}"; copied="${5:-}"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  body="{\"phase\":\"$(json_escape "$phase")\",\"last_completed_phase\":\"$(json_escape "$last")\",\"updated_at\":\"$now\",\"last_error\":\"$(json_escape "$err")\",\"keys_copied\":\"$(json_escape "$copied")\"}"
  state_set "dataset-$dataset" "$body"
}

target_key_allowed() {
  target_db="$1"
  while IFS='	' read -r _ source_db configured_target pattern; do
    [ -z "${configured_target:-}" ] && continue
    [ "$target_db" = "$configured_target" ] && return 0
  done <<EOF
$DATASETS_TSV
EOF
  echo "REFUSED: target db $target_db is not configured for this resource" >&2
  return 1
}

dbsize() {
  side="$1"; db="$2"
  redis_cli_timed "$side" "$db" DBSIZE | strip_cr
}

memory_used() {
  side="$1"; db="$2"
  redis_cli_timed "$side" "$db" INFO memory | awk -F: '/^used_memory:/ {gsub(/\r/,"",$2); print $2; found=1} END {if (!found) print "unknown"}'
}

redis_shake_download_url() {
  if [ -n "${REDIS_SHAKE_DOWNLOAD_URL:-}" ]; then
    printf '%s' "$REDIS_SHAKE_DOWNLOAD_URL"
    return 0
  fi
  case "$(uname -m)" in
    x86_64|amd64)
      arch="amd64"
      ;;
    aarch64|arm64)
      arch="arm64"
      ;;
    *)
      echo "REFUSED: unsupported architecture for RedisShake: $(uname -m)" >&2
      return 1
      ;;
  esac
  curl -fsSL "https://api.github.com/repos/tair-opensource/RedisShake/releases/latest" \
    | jq -r --arg arch "$arch" '.assets[].browser_download_url | select(test("linux.*" + $arch + ".*\\.tar\\.gz$"))' \
    | head -n 1
}

ensure_redis_shake() {
  if command -v "${REDIS_SHAKE_BIN:-redis-shake}" >/dev/null 2>&1; then
    REDIS_SHAKE_BIN="$(command -v "${REDIS_SHAKE_BIN:-redis-shake}")"
    export REDIS_SHAKE_BIN
    return 0
  fi
  if command -v apk >/dev/null 2>&1; then
    apk add --no-cache ca-certificates tar gzip >/dev/null
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update >/dev/null && apt-get install -y ca-certificates tar gzip >/dev/null
  fi
  url="$(redis_shake_download_url)"
  [ -n "$url" ] || {
    echo "REFUSED: could not resolve RedisShake download URL" >&2
    return 1
  }
  workdir="${REDIS_SHAKE_WORKDIR:-/tmp/redis-shake-bin}"
  mkdir -p "$workdir"
  curl -fsSL "$url" -o "$workdir/redis-shake.tar.gz"
  tar -xzf "$workdir/redis-shake.tar.gz" -C "$workdir"
  bin="$(find "$workdir" -type f -name redis-shake -perm -111 | head -n 1)"
  [ -n "$bin" ] || {
    echo "REFUSED: RedisShake binary not found in release archive" >&2
    return 1
  }
  REDIS_SHAKE_BIN="$bin"
  export REDIS_SHAKE_BIN
}

redis_shake_filter_for_pattern() {
  pattern="$1"
  case "$pattern" in
    '*')
      printf 'allow_key_prefix = []\nallow_key_suffix = []\nallow_key_regex = []\n'
      ;;
    *'*')
      prefix="${pattern%\*}"
      case "$prefix" in
        *'*'*|*'?'*|'')
          echo "REFUSED: RedisShake supports '*' or simple prefix patterns like 'foo:*'; got '$pattern'" >&2
          return 1
          ;;
        *)
          printf 'allow_key_prefix = ["%s"]\nallow_key_suffix = []\nallow_key_regex = []\n' "$(toml_escape "$prefix")"
          ;;
      esac
      ;;
    *)
      printf 'allow_key_prefix = []\nallow_key_suffix = []\nallow_key_regex = ["^%s$"]\n' "$(toml_escape "$pattern")"
      ;;
  esac
}

write_redis_shake_config() {
  name="$1"; source_db="$2"; target_db="$3"; pattern="$4"; config_file="$5"
  if [ "$source_db" != "$target_db" ]; then
    echo "REFUSED: RedisShake scan restore requires source_db and target_db to match; got source_db=$source_db target_db=$target_db" >&2
    return 1
  fi
  filter_config="$(redis_shake_filter_for_pattern "$pattern")" || return 1
  restore_behavior="panic"
  [ "${RESTORE_REPLACE:-false}" = "true" ] && restore_behavior="rewrite"
  mkdir -p "$(dirname "$config_file")" "/tmp/redis-shake-$name"
  cat > "$config_file" <<EOF
type = "scan_reader"

[scan_reader]
cluster = false
address = "$(toml_escape "$SOURCE_HOST"):${SOURCE_PORT}"
username = ""
password = "$(toml_escape "${SOURCE_AUTH_TOKEN:-}")"
tls = $(toml_bool "${SOURCE_TLS:-false}")
dbs = [${source_db}]
scan = true
ksn = false
count = ${SCAN_COUNT:-1000}
skip_unknown_type = []

[redis_writer]
cluster = false
address = "$(toml_escape "$TARGET_HOST"):${TARGET_PORT}"
username = ""
password = "$(toml_escape "${TARGET_AUTH_TOKEN:-}")"
tls = $(toml_bool "${TARGET_TLS:-false}")
off_reply = false

[filter]
$filter_config
block_key_prefix = []
block_key_suffix = []
block_key_regex = []
allow_db = [${source_db}]
block_db = []

[advanced]
dir = "/tmp/redis-shake-$name"
ncpu = ${REDIS_SHAKE_NCPU:-0}
log_file = "/tmp/redis-shake-$name.log"
log_level = "${REDIS_SHAKE_LOG_LEVEL:-info}"
log_interval = 5
rdb_restore_command_behavior = "$restore_behavior"
pipeline_count_limit = ${REDIS_SHAKE_PIPELINE_COUNT_LIMIT:-1024}
target_redis_max_qps = ${REDIS_SHAKE_TARGET_MAX_QPS:-100000}
EOF
}

preflight_dataset() {
  name="$1"; source_db="$2"; target_db="$3"; pattern="$4"
  echo "== PREFLIGHT $name =="
  write_dataset_state "$name" PREFLIGHT "" ""
  source_ping="$(redis_cli_timed source "$source_db" PING 2>&1 | strip_cr || true)"
  target_ping="$(redis_cli_timed target "$target_db" PING 2>&1 | strip_cr || true)"
  echo "source_ping=$source_ping"
  echo "target_ping=$target_ping"
  if [ "$source_ping" != "PONG" ] || [ "$target_ping" != "PONG" ]; then
    write_dataset_state "$name" PREFLIGHT "" "redis ping failed" ""
    return 1
  fi
  source_dbsize="$(dbsize source "$source_db" 2>&1 | strip_cr || true)"
  target_dbsize="$(dbsize target "$target_db" 2>&1 | strip_cr || true)"
  echo "source_dbsize=$source_dbsize"
  echo "target_dbsize=$target_dbsize"
  if ! is_uint "$source_dbsize" || ! is_uint "$target_dbsize"; then
    write_dataset_state "$name" PREFLIGHT "" "redis dbsize failed" ""
    return 1
  fi
  echo "source_used_memory=$(memory_used source "$source_db")"
  echo "target_used_memory=$(memory_used target "$target_db")"
  echo "pattern=$pattern"
  write_dataset_state "$name" PREFLIGHT PREFLIGHT ""
}

reset_target_dataset() {
  name="$1"; source_db="$2"; target_db="$3"; pattern="$4"
  target_key_allowed "$target_db"
  if [ "${ALLOW_TARGET_RESET:-false}" != "true" ]; then
    echo "REFUSED: allow_target_reset=false; not flushing target db $target_db" >&2
    return 1
  fi
  echo "== RESET TARGET $name target_db=$target_db =="
  write_dataset_state "$name" RESET_TARGET "" ""
  redis_cli target "$target_db" FLUSHDB >/dev/null
  write_dataset_state "$name" RESET_TARGET RESET_TARGET ""
}

restore_one_key() {
  source_db="$1"; target_db="$2"; key="$3"; workdir="$4"
  dump_file="$workdir/dump.bin"
  ttl="$(redis_cli source "$source_db" PTTL "$key" | tr -d '\r')"
  [ "${COPY_TTL:-true}" = "true" ] || ttl=0
  [ "$ttl" = "-1" ] && ttl=0
  [ "$ttl" = "-2" ] && return 0
  redis_cli_timed source "$source_db" --raw DUMP "$key" > "$dump_file"
  if [ "${RESTORE_REPLACE:-false}" = "true" ]; then
    redis_cli_timed target "$target_db" -x RESTORE "$key" "$ttl" REPLACE < "$dump_file" >/dev/null
  else
    redis_cli_timed target "$target_db" -x RESTORE "$key" "$ttl" < "$dump_file" >/dev/null
  fi
}

restore_dataset_redis_shake() {
  name="$1"; source_db="$2"; target_db="$3"; pattern="$4"
  echo "== RESTORE $name engine=redis-shake source_db=$source_db target_db=$target_db pattern=$pattern =="
  write_dataset_state "$name" LOAD "" ""
  target_count="$(dbsize target "$target_db")"
  if [ "$target_count" != "0" ] && [ "${REQUIRE_EMPTY_TARGET:-true}" = "true" ] && [ "${ALLOW_TARGET_RESET:-false}" != "true" ]; then
    echo "REFUSED: target db $target_db has $target_count keys; set allow_target_reset=true and run reset-target or disable require_empty_target" >&2
    write_dataset_state "$name" LOAD "" "target not empty" ""
    return 1
  fi
  if [ "$target_count" != "0" ] && [ "${ALLOW_TARGET_RESET:-false}" = "true" ]; then
    reset_target_dataset "$name" "$source_db" "$target_db" "$pattern"
  fi
  ensure_redis_shake
  workdir="$(mktemp -d)"
  config_file="$workdir/shake-$name.toml"
  write_redis_shake_config "$name" "$source_db" "$target_db" "$pattern" "$config_file"
  echo "redis_shake_bin=$REDIS_SHAKE_BIN"
  echo "redis_shake_config=$config_file"
  if ! "$REDIS_SHAKE_BIN" "$config_file"; then
    if [ -f "/tmp/redis-shake-$name.log" ]; then
      echo "== RedisShake log tail =="
      tail -n 100 "/tmp/redis-shake-$name.log" || true
    fi
    write_dataset_state "$name" LOAD "" "redis-shake failed" ""
    return 1
  fi
  target_after="$(dbsize target "$target_db")"
  write_dataset_state "$name" LOAD LOAD "" "$target_after"
  echo "target_dbsize_after=$target_after"
}

restore_dataset() {
  name="$1"; source_db="$2"; target_db="$3"; pattern="$4"
  if [ "${RESTORE_ENGINE:-shell}" = "redis-shake" ]; then
    restore_dataset_redis_shake "$name" "$source_db" "$target_db" "$pattern"
    return $?
  fi
  echo "== RESTORE $name source_db=$source_db target_db=$target_db pattern=$pattern =="
  write_dataset_state "$name" LOAD "" ""
  target_count="$(dbsize target "$target_db")"
  if [ "$target_count" != "0" ] && [ "${REQUIRE_EMPTY_TARGET:-true}" = "true" ] && [ "${ALLOW_TARGET_RESET:-false}" != "true" ]; then
    echo "REFUSED: target db $target_db has $target_count keys; set allow_target_reset=true and run reset-target or disable require_empty_target" >&2
    write_dataset_state "$name" LOAD "" "target not empty" ""
    return 1
  fi
  if [ "$target_count" != "0" ] && [ "${ALLOW_TARGET_RESET:-false}" = "true" ]; then
    reset_target_dataset "$name" "$source_db" "$target_db" "$pattern"
  fi
  copied=0
  workdir="$(mktemp -d)"
  trap 'rm -rf "$workdir"' EXIT
  redis_cli source "$source_db" --scan --pattern "$pattern" --count "${SCAN_COUNT:-1000}" | while IFS= read -r key; do
    [ -z "$key" ] && continue
    restore_one_key "$source_db" "$target_db" "$key" "$workdir"
    copied=$((copied + 1))
    if [ $((copied % 1000)) -eq 0 ]; then
      echo "copied=$copied"
      write_dataset_state "$name" LOAD "" "" "$copied"
    fi
  done
  target_after="$(dbsize target "$target_db")"
  write_dataset_state "$name" LOAD LOAD "" "$target_after"
  echo "target_dbsize_after=$target_after"
}

verify_dataset() {
  name="$1"; source_db="$2"; target_db="$3"; pattern="$4"
  echo "== VERIFY $name =="
  write_dataset_state "$name" VERIFY "" ""
  source_count="$(dbsize source "$source_db")"
  target_count="$(dbsize target "$target_db")"
  echo "source_dbsize=$source_count"
  echo "target_dbsize=$target_count"
  checked=0
  missing=0
  limit="${SAMPLE_LIMIT:-25}"
  if [ "$limit" != "0" ]; then
    sample_file="$(mktemp)"
    redis_cli_timed source "$source_db" --scan --pattern "$pattern" --count "${SCAN_COUNT:-1000}" | sed -n "1,${limit}p" > "$sample_file"
    while IFS= read -r key; do
      [ -z "$key" ] && continue
      exists="$(redis_cli_timed target "$target_db" EXISTS "$key" | tr -d '\r')"
      [ "$exists" = "1" ] || missing=$((missing + 1))
      checked=$((checked + 1))
      [ "$checked" -ge "$limit" ] && break
    done < "$sample_file"
    rm -f "$sample_file"
  fi
  echo "sample_checked=$checked"
  echo "sample_missing=$missing"
  write_dataset_state "$name" VERIFY VERIFY "" ""
}

status_summary() {
  echo "Redis dump restore status"
  echo "source=$SOURCE_HOST:$SOURCE_PORT target=$TARGET_HOST:$TARGET_PORT"
  while IFS='	' read -r name source_db target_db pattern; do
    [ -z "${name:-}" ] && continue
    state="$(state_get "dataset-$name")"
    [ -n "$state" ] || state='{"phase":"NEW"}'
    echo "$name source_db=$source_db target_db=$target_db pattern=$pattern state=$state"
  done <<EOF
$DATASETS_TSV
EOF
}

run_for_each_dataset() {
  action="$1"
  while IFS='	' read -r name source_db target_db pattern; do
    [ -z "${name:-}" ] && continue
    "$action" "$name" "$source_db" "$target_db" "$pattern"
  done <<EOF
$DATASETS_TSV
EOF
}

main() {
  need_tools || {
    echo "REFUSED: runner image must contain redis-cli or valkey-cli" >&2
    return 1
  }
  case "$mode" in
    preflight)
      run_for_each_dataset preflight_dataset
      ;;
    run)
      run_for_each_dataset preflight_dataset
      run_for_each_dataset restore_dataset
      run_for_each_dataset verify_dataset
      ;;
    reset-target)
      run_for_each_dataset reset_target_dataset
      ;;
    verify)
      run_for_each_dataset verify_dataset
      ;;
    status)
      status_summary
      ;;
    *)
      echo "unknown mode: $mode" >&2
      return 1
      ;;
  esac
}

if [ "${REDIS_DUMP_RESTORE_LIB_ONLY:-false}" != "true" ]; then
  main "$@"
fi

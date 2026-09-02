#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/scripts"

if [ ! -f "$SCRIPT_DIR/dump_restore.sh" ]; then
  echo "missing redis dump_restore.sh"
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/scripts"
cp "$SCRIPT_DIR/dump_restore.sh" "$tmpdir/scripts/dump_restore.sh"

cat > "$tmpdir/scripts/config.sh" <<'EOF'
SOURCE_HOST=source.redis.internal
SOURCE_PORT=6379
SOURCE_AUTH_TOKEN=
SOURCE_TLS=false
TARGET_HOST=target.redis.internal
TARGET_PORT=6379
TARGET_AUTH_TOKEN=
TARGET_TLS=false
STATE_CONFIGMAP=redis-stage-state
NAMESPACE=default
ALLOW_TARGET_RESET=false
REQUIRE_EMPTY_TARGET=true
RESTORE_REPLACE=false
COPY_TTL=true
SCAN_COUNT=1000
SAMPLE_LIMIT=25
RESTORE_ENGINE=shell
REDIS_SHAKE_PIPELINE_COUNT_LIMIT=1024
REDIS_SHAKE_TARGET_MAX_QPS=100000
REDIS_SHAKE_LOG_LEVEL=info
REDIS_SHAKE_DOWNLOAD_URL=
DATASETS_TSV='cache	0	0	foo:*'
EOF

export REDIS_DUMP_RESTORE_SCRIPT_DIR="$tmpdir/scripts"
export REDIS_DUMP_RESTORE_LIB_ONLY=true

assert_contains() {
  haystack="$1"
  needle="$2"
  case "$haystack" in
    *"$needle"*) ;;
    *)
      echo "expected to contain: $needle" >&2
      echo "actual: $haystack" >&2
      exit 1
      ;;
  esac
}

assert_not_contains() {
  haystack="$1"
  needle="$2"
  case "$haystack" in
    *"$needle"*)
      echo "expected not to contain: $needle" >&2
      echo "actual: $haystack" >&2
      exit 1
      ;;
    *) ;;
  esac
}

(
  cd "$tmpdir"
  . scripts/dump_restore.sh

  source_cmd="$(redis_cli_base source 4)"
  assert_contains "$source_cmd" "-h source.redis.internal"
  assert_contains "$source_cmd" "-p 6379"
  assert_contains "$source_cmd" "-n 4"
  assert_not_contains "$source_cmd" "--tls"
  assert_not_contains "$source_cmd" "-a"

  SOURCE_TLS=true
  SOURCE_AUTH_TOKEN=secret
  source_tls_cmd="$(redis_cli_base source 3)"
  assert_contains "$source_tls_cmd" "--tls"
  assert_contains "$source_tls_cmd" "--no-auth-warning"
  assert_contains "$source_tls_cmd" "-a secret"

  target_cmd="$(redis_cli_base target 5)"
  assert_contains "$target_cmd" "-h target.redis.internal"
  assert_contains "$target_cmd" "-n 5"

  target_key_allowed 0
  if target_key_allowed 1 >/dev/null 2>&1; then
    echo "expected unknown target db to be rejected"
    exit 1
  fi
)

(
  cd "$tmpdir"
  . scripts/dump_restore.sh
  ALLOW_TARGET_RESET=false
  if reset_target_dataset cache 0 0 'foo:*' >/tmp/reset.out 2>/tmp/reset.err; then
    echo "expected reset to be blocked"
    exit 1
  fi
  assert_contains "$(cat /tmp/reset.err)" "REFUSED: allow_target_reset=false"
)

(
  cd "$tmpdir"
  . scripts/dump_restore.sh
  SOURCE_TLS=true
  TARGET_TLS=false
  RESTORE_REPLACE=true
  REDIS_SHAKE_PIPELINE_COUNT_LIMIT=2048
  REDIS_SHAKE_TARGET_MAX_QPS=75000
  config_file="$tmpdir/shake.toml"
  write_redis_shake_config cache 0 0 'foo:*' "$config_file"
  config="$(cat "$config_file")"
  assert_contains "$config" "[scan_reader]"
  assert_contains "$config" "address = \"source.redis.internal:6379\""
  assert_contains "$config" "tls = true"
  assert_contains "$config" "dbs = [0]"
  assert_contains "$config" "count = 1000"
  assert_contains "$config" "[redis_writer]"
  assert_contains "$config" "address = \"target.redis.internal:6379\""
  assert_contains "$config" "tls = false"
  assert_contains "$config" "allow_key_prefix = [\"foo:\"]"
  assert_contains "$config" "allow_db = [0]"
  assert_contains "$config" "rdb_restore_command_behavior = \"rewrite\""
  assert_contains "$config" "pipeline_count_limit = 2048"
  assert_contains "$config" "target_redis_max_qps = 75000"
)

(
  cd "$tmpdir"
  . scripts/dump_restore.sh
  if write_redis_shake_config cache 0 1 '*' "$tmpdir/bad-shake.toml" >/tmp/shake.out 2>/tmp/shake.err; then
    echo "expected redis-shake config to reject source/target db remap"
    exit 1
  fi
  assert_contains "$(cat /tmp/shake.err)" "requires source_db and target_db to match"
)

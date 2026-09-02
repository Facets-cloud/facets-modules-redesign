#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/scripts"
cp "$(dirname "$0")/../scripts/dump_restore.sh" "$tmpdir/scripts/dump_restore.sh"
cat > "$tmpdir/scripts/config.sh" <<'EOF'
SOURCE_HOST=source
SOURCE_PORT=3306
SOURCE_ADMIN_USER=user
TARGET_HOST=target
TARGET_PORT=3306
TARGET_ADMIN_USER=user
STATE_CONFIGMAP=test-state
NAMESPACE=default
ALLOW_TARGET_RESET=false
REQUIRE_EMPTY_TARGET=true
FORCE_UTC=true
DEFAULT_CHARACTER_SET=utf8mb4
ALLOW_CHARSET_MISMATCH=false
ALLOW_COLLATION_MISMATCH=false
ALLOW_NON_INNODB=false
STRIP_DEFINERS=true
MIN_MAX_ALLOWED_PACKET_BYTES=67108864
LOCK_TIMEOUT_SECONDS=60
DATABASES_TSV='app	source_db	target_db	source_db.skip_me,source_db.old	true	true	false'
EOF

export SOURCE_ADMIN_PASSWORD=unused
export TARGET_ADMIN_PASSWORD=unused
export MYSQL_DUMP_RESTORE_LIB_ONLY=true
export MYSQL_DUMP_RESTORE_SCRIPT_DIR="$tmpdir/scripts"

(
  cd "$tmpdir"
  source scripts/dump_restore.sh

  [ "$(sql_ident target_db)" = '`target_db`' ]
  if sql_ident 'bad`name' >/dev/null 2>&1; then
    echo "expected sql_ident to reject backtick" >&2
    exit 1
  fi

  assert_known_target_db target_db
  if assert_known_target_db other_db >/dev/null 2>&1; then
    echo "expected unknown target db to be rejected" >&2
    exit 1
  fi

  args="$(dump_args_for_db source_db 'source_db.skip_me,source_db.old' true false false)"
  case "$args" in
    *"--ignore-table=source_db.skip_me"*"--ignore-table=source_db.old"* ) ;;
    *)
      echo "missing ignore table args: $args" >&2
      exit 1
      ;;
  esac
  [[ "$args" == *"--routines"* ]]
  [[ "$args" == *"--skip-triggers"* ]]
  [[ "$args" == *"--skip-events"* ]]
  [[ "$args" == *"--no-tablespaces"* ]]

  empty_args="$(dump_args_for_db source_db '' true true false)"
  if [[ "$empty_args" == *"--ignore-table="* ]]; then
    echo "empty excludes must not emit ignore-table args: $empty_args" >&2
    exit 1
  fi
  null_args="$(dump_args_for_db source_db 'null' true true false)"
  if [[ "$null_args" == *"--ignore-table="* ]]; then
    echo "null excludes must not emit ignore-table args: $null_args" >&2
    exit 1
  fi
  none_args="$(dump_args_for_db source_db '__none__' true true false)"
  if [[ "$none_args" == *"--ignore-table="* ]]; then
    echo "__none__ excludes must not emit ignore-table args: $none_args" >&2
    exit 1
  fi

  PATH=/no-kubectl-here state_set smoke value
  [ "$(PATH=/no-kubectl-here state_get smoke)" = "" ]
  [ "$(PATH=/no-kubectl-here status_dump)" = "{}" ]

  export SLACK_CHANNEL_ID=C123
  export SLACK_TOKEN=unused
  curl() { return 1; }
  PATH=/no-kubectl-here slack_update

  source_sql() {
    return 1
  }
  target_sql() {
    echo "8.0.45"
  }
  if preflight_db app source_db target_db "" >/tmp/preflight-auth.out 2>&1; then
    echo "expected preflight to fail when source query fails" >&2
    exit 1
  fi
  grep -q "REFUSED: source query failed" /tmp/preflight-auth.out
)

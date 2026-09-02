#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/scripts"
cp "$(dirname "$0")/../scripts/dump_restore.sh" "$tmpdir/scripts/dump_restore.sh"
cat > "$tmpdir/scripts/config.sh" <<'EOF'
SOURCE_HOST=docdb.example.internal
SOURCE_PORT=27017
SOURCE_ADMIN_USER=source_user
SOURCE_AUTH_DATABASE=admin
SOURCE_TLS=true
SOURCE_TLS_ALLOW_INVALID_CERTIFICATES=true
SOURCE_REPLICA_SET=rs0
SOURCE_EXTRA_URI_OPTIONS=retryWrites=false
TARGET_HOST=mongo.default.svc
TARGET_PORT=27017
TARGET_ADMIN_USER=target
TARGET_AUTH_DATABASE=admin
TARGET_TLS=false
TARGET_TLS_ALLOW_INVALID_CERTIFICATES=false
TARGET_REPLICA_SET=
TARGET_EXTRA_URI_OPTIONS=
STATE_CONFIGMAP=test-state
NAMESPACE=default
ALLOW_TARGET_RESET=false
REQUIRE_EMPTY_TARGET=true
GZIP=true
NUM_PARALLEL_COLLECTIONS=4
DATABASES_TSV='app	source_db	target_db	source_db.skip_me,source_db.old	false'
EOF

export SOURCE_ADMIN_PASSWORD='source pass/word'
export TARGET_ADMIN_PASSWORD='target pass'
export MONGO_DUMP_RESTORE_LIB_ONLY=true
export MONGO_DUMP_RESTORE_SCRIPT_DIR="$tmpdir/scripts"

assert_contains() {
  local haystack="$1" needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "expected to contain: $needle" >&2
    echo "actual: $haystack" >&2
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "expected not to contain: $needle" >&2
    echo "actual: $haystack" >&2
    exit 1
  fi
}

(
  cd "$tmpdir"
  source scripts/dump_restore.sh

  source_uri="$(mongo_uri source source_db)"
  [[ "$source_uri" == mongodb://source_user:source%20pass%2Fword@docdb.example.internal:27017/source_db* ]]
  assert_contains "$source_uri" "authSource=admin"
  assert_contains "$source_uri" "tls=true"
  assert_contains "$source_uri" "tlsInsecure=true"
  assert_contains "$source_uri" "replicaSet=rs0"
  assert_contains "$source_uri" "retryWrites=false"

  target_uri="$(mongo_uri target target_db)"
  [[ "$target_uri" == mongodb://target:target%20pass@mongo.default.svc:27017/target_db* ]]
  assert_contains "$target_uri" "authSource=admin"
  assert_not_contains "$target_uri" "tls=true"

  dump_args="$(dump_args_for_db source_db 'source_db.skip_me,source_db.old')"
  assert_contains "$dump_args" "--archive"
  assert_contains "$dump_args" "--gzip"
  assert_contains "$dump_args" "--excludeCollection source_db.skip_me"
  assert_contains "$dump_args" "--excludeCollection source_db.old"

  empty_args="$(dump_args_for_db source_db '__none__')"
  assert_not_contains "$empty_args" "--excludeCollection"

  restore_args="$(restore_args_for_db source_db target_db false)"
  assert_contains "$restore_args" "--noOptionsRestore"
  assert_contains "$restore_args" "--nsInclude source_db.\\*"
  assert_contains "$restore_args" "--nsFrom source_db.\\*"
  assert_contains "$restore_args" "--nsTo target_db.\\*"
  assert_not_contains "$restore_args" "--preserveUUID"

  preserve_args="$(restore_args_for_db source_db target_db true)"
  assert_contains "$preserve_args" "--preserveUUID"

  assert_known_target_db target_db
  if assert_known_target_db other_db >/dev/null 2>&1; then
    echo "expected unknown target db to be rejected" >&2
    exit 1
  fi
)

(
  cd "$tmpdir"
  source scripts/dump_restore.sh

  ALLOW_TARGET_RESET=false
  collection_count() { echo 3; }
  verify_db() { echo "verify_called"; }
  reset_target_db() {
    echo "reset should not be called" >&2
    exit 1
  }
  dump_args_for_db() {
    echo "dump should not be called" >&2
    exit 1
  }
  restore_args_for_db() {
    echo "restore should not be called" >&2
    exit 1
  }
  write_db_state() { :; }

  output="$(restore_db app source_db target_db __none__ false)"
  assert_contains "$output" "target has 3 collections; verifying existing restore instead of resetting"
  assert_contains "$output" "verify_called"
)

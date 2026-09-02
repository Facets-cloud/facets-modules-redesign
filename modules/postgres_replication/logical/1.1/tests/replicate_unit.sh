#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
MODULE_DIR="$(dirname "$SCRIPT_DIR")"

export POSTGRES_REPLICATION_LIB_ONLY=true
export DATABASES_JSON='[{"name":"citadel_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub"}]'
export SOURCE_ADMIN_PASSWORD='source-admin-secret'
export SOURCE_REPL_PASSWORD='source-repl-secret'
export TARGET_ADMIN_PASSWORD='target-admin-secret'
export TARGET_REPL_PASSWORD='target-repl-secret'
export SLACK_BOT_TOKEN='xoxp-secret-token'
export SOURCE_HOST='source.example.internal'
export SOURCE_PORT='5432'
export SOURCE_ADMIN_USER='source_admin'
export SOURCE_REPL_USER='source_repl'
export SOURCE_AUTH_DB=''
export TARGET_HOST='10.60.0.10'
export TARGET_PORT='5432'
export TARGET_ADMIN_USER='target_admin'
export TARGET_REPL_USER='target_repl'
export TARGET_LOGIN_ROLES_JSON='[]'
export TARGET_LOGIN_ROLE_PASSWORDS_JSON='{}'
export REQUIRE_TARGET_LOGIN_ROLES=false
export ALLOW_SCHEMA_RESET=false
export ALLOW_MUTATION=true
export NAMESPACE=default
export STATE_CONFIGMAP=citadel-state
export SLACK_CHANNEL_ID=C0BPY1LME74
export WORK_DIR="${TMPDIR:-/tmp}/replicate-unit-$$"
mkdir -p "$WORK_DIR"

. "$MODULE_DIR/scripts/replicate.sh"

fail() {
  echo "not ok - $1" >&2
  exit 1
}

assert_contains() {
  haystack="$1"
  needle="$2"
  name="$3"
  printf '%s' "$haystack" | grep -F -- "$needle" >/dev/null || fail "$name"
}

assert_not_contains() {
  haystack="$1"
  needle="$2"
  name="$3"
  if printf '%s' "$haystack" | grep -F -- "$needle" >/dev/null; then
    fail "$name"
  fi
}

redacted="$(printf '%s' 'psql: connection failed password=abc123 source-admin-secret source-repl-secret target-admin-secret target-repl-secret xoxp-secret-token' | sanitize_error)"
assert_contains "$redacted" 'password=[REDACTED]' 'password=... is redacted'
assert_not_contains "$redacted" 'source-admin-secret' 'source admin password is redacted'
assert_not_contains "$redacted" 'source-repl-secret' 'source repl password is redacted'
assert_not_contains "$redacted" 'target-admin-secret' 'target admin password is redacted'
assert_not_contains "$redacted" 'target-repl-secret' 'target repl password is redacted'
assert_not_contains "$redacted" 'xoxp-secret-token' 'slack token is redacted'

export SOURCE_AUTH_DB=''
[ "$(source_auth_db_for src)" = "src" ] || fail 'source auth db defaults to the requested source database'
export SOURCE_AUTH_DB='postgres'
[ "$(source_auth_db_for src)" = "postgres" ] || fail 'source auth db override is honored'
export SOURCE_AUTH_DB=''

export DATABASES_JSON='[{"name":"citadel_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub"}]'
if cat <<'SQL' | sanitize_pg_dump_sql citadel_db >/tmp/sanitize-unsupported.out 2>/tmp/sanitize-unsupported.err; then
SET transaction_timeout = 0;
CREATE EXTENSION IF NOT EXISTS aws_commons WITH SCHEMA public;
SQL
  fail 'schema sanitizer must fail safe on unsupported aws_commons unless excluded'
fi
assert_contains "$(cat /tmp/sanitize-unsupported.err)" 'REFUSED: unsupported extension aws_commons in source schema' 'schema sanitizer reports unsupported extension'
assert_contains "$(cat /tmp/sanitize-unsupported.err)" 'exclude_extensions' 'schema sanitizer tells operator how to explicitly skip'

export DATABASES_JSON='[{"name":"citadel_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub","exclude_extensions":["aws_commons"]}]'
sanitized_dump="$(cat <<'SQL' | sanitize_pg_dump_sql citadel_db 2>/tmp/sanitize-excluded.err
SET transaction_timeout = 0;
CREATE EXTENSION IF NOT EXISTS aws_commons WITH SCHEMA public;
COMMENT ON EXTENSION aws_commons IS 'AWS helper extension';
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;
SQL
)"
assert_not_contains "$sanitized_dump" 'aws_commons' 'schema sanitizer strips explicitly excluded aws_commons extension DDL'
assert_contains "$sanitized_dump" 'CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;' 'schema sanitizer preserves non-AWS extension DDL'
assert_not_contains "$sanitized_dump" 'SET transaction_timeout' 'schema sanitizer strips unsupported transaction_timeout'
assert_contains "$(cat /tmp/sanitize-excluded.err)" 'WARNING: skipping excluded extension aws_commons' 'schema sanitizer logs explicit extension skip'

export DATABASES_JSON='[{"name":"citadel_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub"}]'

if (
  pg_dump() {
    cat <<'SQL'
CREATE EXTENSION IF NOT EXISTS aws_s3 WITH SCHEMA public;
SQL
  }

  ensure_target_login_roles() {
    :
  }

  schema_reset_sql() {
    fail 'schema_db must not reset target when schema sanitizer refuses unsupported extension'
  }

  target_psql() {
    fail 'schema_db must not replay target SQL when schema sanitizer refuses unsupported extension'
  }

  schema_db citadel_db
) >/tmp/schema-sanitize-fail.out 2>/tmp/schema-sanitize-fail.err; then
  fail 'schema_db must fail when sanitizer refuses unsupported extension'
fi
assert_contains "$(cat /tmp/schema-sanitize-fail.err)" 'REFUSED: unsupported extension aws_s3 in source schema' 'schema_db surfaces sanitizer failure'

state_get() {
  key="$1"
  case "$key" in
    db-citadel_db)
      printf '%s' '{"phase":"SCHEMA","last_completed_phase":"PUBLISH","phase_started_epoch":100,"phase_durations":{"PREFLIGHT":4,"PUBLISH":2},"last_error":""}'
      ;;
    *)
      printf ''
      ;;
  esac
}

current_epoch() {
  echo 111
}

state_json="$(build_db_state citadel_db SCHEMA SCHEMA "" 0 0 true)"
schema_duration="$(printf '%s' "$state_json" | jq -r '.phase_durations.SCHEMA')"
preflight_duration="$(printf '%s' "$state_json" | jq -r '.phase_durations.PREFLIGHT')"
[ "$schema_duration" = "11" ] || fail 'completed phase duration is recorded'
[ "$preflight_duration" = "4" ] || fail 'existing phase durations are preserved'

target_public_objects() {
  printf '%s\n' 'public.aadhaar_vault' 'public.pii_vault'
}

if schema_reset_sql citadel_db >/tmp/schema-reset.sql 2>/tmp/schema-reset.err; then
  fail 'forward non-empty schema reset without opt-in must fail'
fi
assert_contains "$(cat /tmp/schema-reset.err)" 'REFUSED: target schema public is not empty' 'schema reset refusal names the reason'
assert_contains "$(cat /tmp/schema-reset.err)" 'public.aadhaar_vault' 'schema reset refusal names first object'
assert_contains "$(cat /tmp/schema-reset.err)" 'public.pii_vault' 'schema reset refusal names second object'
assert_not_contains "$(cat /tmp/schema-reset.sql)" 'DROP SCHEMA' 'schema reset refusal does not emit drop'

ALLOW_SCHEMA_RESET=true
sql="$(schema_reset_sql citadel_db)"
assert_contains "$sql" 'DROP SCHEMA IF EXISTS public CASCADE;' 'forward opt-in emits drop for non-empty schema'

target_public_objects() {
  printf ''
}

ALLOW_MUTATION=true
ALLOW_SCHEMA_RESET=false
sql="$(schema_reset_sql citadel_db)"
assert_not_contains "$sql" 'DROP SCHEMA' 'empty schema path does not drop'
assert_contains "$sql" 'CREATE SCHEMA IF NOT EXISTS public;' 'empty schema path creates schema idempotently'

cat > "$WORK_DIR/pre-data-schemas.sql" <<'SQL'
CREATE SCHEMA plutus;
CREATE SCHEMA "quoted_schema";
SQL
target_schema_objects() {
  target_db="$1"
  schema="$2"
  case "$schema" in
    public)
      printf '%s\n' 'public.aadhaar_vault'
      ;;
    plutus)
      printf '%s\n' 'plutus.*'
      ;;
    quoted_schema)
      printf ''
      ;;
    *)
      fail "unexpected schema object check for $target_db.$schema"
      ;;
  esac
}
ALLOW_SCHEMA_RESET=false
if schema_reset_sql citadel_db "$WORK_DIR/pre-data-schemas.sql" >/tmp/schema-reset-multi.sql 2>/tmp/schema-reset-multi.err; then
  fail 'forward non-empty multi-schema reset without opt-in must fail'
fi
assert_contains "$(cat /tmp/schema-reset-multi.err)" 'plutus.*' 'schema reset refusal includes existing non-public schema'
assert_not_contains "$(cat /tmp/schema-reset-multi.sql)" 'DROP SCHEMA' 'multi-schema reset refusal does not emit drop'
ALLOW_SCHEMA_RESET=true
sql="$(schema_reset_sql citadel_db "$WORK_DIR/pre-data-schemas.sql")"
assert_contains "$sql" 'DROP SCHEMA IF EXISTS public CASCADE;' 'multi-schema reset drops public'
assert_contains "$sql" 'DROP SCHEMA IF EXISTS "plutus" CASCADE;' 'multi-schema reset drops source dump schema'
assert_contains "$sql" 'DROP SCHEMA IF EXISTS "quoted_schema" CASCADE;' 'multi-schema reset quotes source dump schema'
assert_contains "$sql" 'CREATE SCHEMA public;' 'multi-schema reset recreates public'
target_schema_objects() {
  printf ''
}

if grep -n '^[[:space:]]*token="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"' "$MODULE_DIR/scripts/replicate.sh" >/tmp/shared-token-lines; then
  fail "Kubernetes service account token must not use shared global token: $(cat /tmp/shared-token-lines)"
fi

if grep -n 'Authorization: Bearer \$token' "$MODULE_DIR/scripts/replicate.sh" >/tmp/shared-bearer-lines; then
  fail "Authorization headers must use credential-specific variables: $(cat /tmp/shared-bearer-lines)"
fi

if grep -n 'kubectl describe pod' "$MODULE_DIR/actions.tf" >/tmp/unsafe-action-describe-lines; then
  fail "action failure path must not describe pods because env values may include secrets: $(cat /tmp/unsafe-action-describe-lines)"
fi

if grep -n 'SOURCE_AUTH_DB=.*coalesce' "$MODULE_DIR/main.tf" >/tmp/source-auth-coalesce-lines; then
  fail "optional source.auth_db must render without coalesce(empty-string): $(cat /tmp/source-auth-coalesce-lines)"
fi

STATE_DIR="$WORK_DIR/state"
mkdir -p "$STATE_DIR"

state_get() {
  key="$1"
  if [ -f "$STATE_DIR/$key" ]; then
    cat "$STATE_DIR/$key"
  fi
}

state_patch() {
  key="$1"
  value="$2"
  printf '%s' "$value" > "$STATE_DIR/$key"
}

ensure_state() {
  :
}

current_epoch() {
  echo 211
}

current_timestamp() {
  echo '2026-08-13T10:00:00Z'
}

curl() {
  args="$*"
  if printf '%s' "$args" | grep -F 'conversations.history' >/dev/null; then
    echo "history" >> "$STATE_DIR/slack-calls"
    printf '%s' '{"ok":true,"messages":[]}'
    return 0
  fi
  if printf '%s' "$args" | grep -F 'chat.postMessage' >/dev/null; then
    echo "post" >> "$STATE_DIR/slack-calls"
    printf '%s' '{"ok":true,"ts":"222.222"}'
    return 0
  fi
  if printf '%s' "$args" | grep -F 'chat.update' >/dev/null; then
    echo "update" >> "$STATE_DIR/slack-calls"
    printf '%s' '{"ok":true,"ts":"111.111"}'
    return 0
  fi
  printf '%s' '{}'
}

printf '%s' '111.111' > "$STATE_DIR/slack_message_ts"
printf '%s' '{"phase":"STEADY","last_completed_phase":"STEADY","phase_started_epoch":200,"phase_durations":{"PREFLIGHT":4},"tables_ready":7,"tables_total":7,"last_error":""}' > "$STATE_DIR/db-citadel_db"
slack_update >/tmp/slack-update.out 2>/tmp/slack-update.err
assert_contains "$(cat "$STATE_DIR/slack-calls")" 'history' 'slack self-heal checks existing message'
assert_contains "$(cat "$STATE_DIR/slack-calls")" 'post' 'slack self-heal posts fresh when history has no messages'
[ "$(cat "$STATE_DIR/slack_message_ts")" = "222.222" ] || fail 'slack self-heal stores new ts in same invocation'

rm -f "$STATE_DIR"/*
curl() {
  args="$*"
  if printf '%s' "$args" | grep -F 'conversations.history' >/dev/null; then
    echo "history" >> "$STATE_DIR/slack-calls"
    printf '%s' '{"ok":true,"messages":[{"text":"old tracker"}]}'
    return 0
  fi
  if printf '%s' "$args" | grep -F 'chat.update' >/dev/null; then
    echo "update" >> "$STATE_DIR/slack-calls"
    printf '%s' '{"ok":false,"error":"message_not_found"}'
    return 0
  fi
  if printf '%s' "$args" | grep -F 'chat.postMessage' >/dev/null; then
    echo "post" >> "$STATE_DIR/slack-calls"
    printf '%s' '{"ok":true,"ts":"333.333"}'
    return 0
  fi
  printf '%s' '{}'
}

printf '%s' '111.111' > "$STATE_DIR/slack_message_ts"
printf '%s' '{"phase":"STEADY","last_completed_phase":"STEADY","phase_started_epoch":200,"phase_durations":{},"tables_ready":7,"tables_total":7,"last_error":""}' > "$STATE_DIR/db-citadel_db"
slack_update >/tmp/slack-update-missing.out 2>/tmp/slack-update-missing.err
assert_contains "$(cat "$STATE_DIR/slack-calls")" 'update' 'slack self-heal tries update against live ts'
assert_contains "$(cat "$STATE_DIR/slack-calls")" 'post' 'slack self-heal posts fresh when update says message_not_found'
[ "$(cat "$STATE_DIR/slack_message_ts")" = "333.333" ] || fail 'slack self-heal stores replacement ts after message_not_found'

status="$(status_text)"
assert_not_contains "$status" 'Last parity:' 'status omits missing parity'
state_patch last_parity '7/7 tables match'
state_patch last_parity_at '2026-08-13T10:01:00Z'
state_patch last_lag 'slot citadel_sub retained=56B lag=0B'
state_patch last_lag_at '2026-08-13T10:02:00Z'
status="$(status_text)"
assert_contains "$status" 'Last parity check: 7/7 tables match at 2026-08-13T10:01:00Z' 'status renders latest parity check timestamp'
assert_contains "$status" 'WAL retention: slot citadel_sub retained=56B lag=0B at 2026-08-13T10:02:00Z' 'status renders latest WAL retention timestamp'
assert_contains "$status" 'citadel_db: STEADY tables=7/7' 'steady status renders compactly'
assert_not_contains "$status" 'citadel_db: STEADY tables=7/7 elapsed=' 'steady status must not render stale phase elapsed'

rm -f "$STATE_DIR"/*
export STATE_CONFIGMAP=common-pg-stage-state
export DATABASES_JSON='[{"name":"atlas","source_db":"atlas","target_db":"atlas","publication":"atlas_pub","subscription":"atlas_sub"},{"name":"expert_ops","source_db":"expert_ops","target_db":"expert_ops","publication":"expert_pub","subscription":"expert_sub"},{"name":"maestro_core_db","source_db":"maestro_core_db","target_db":"maestro_core_db","publication":"maestro_pub","subscription":"maestro_sub"}]'
state_patch db-atlas '{"phase":"BLOCKED","last_completed_phase":"NONE","phase_started_epoch":200,"phase_durations":{},"tables_ready":0,"tables_total":0,"last_error":"missing_replica_identity=public.geo_hood REFUSED: tables missing replica identity"}'
state_patch db-expert_ops '{"phase":"PREFLIGHT","last_completed_phase":"PREFLIGHT","phase_started_epoch":201,"phase_durations":{"PREFLIGHT":1},"tables_ready":0,"tables_total":0,"last_error":""}'
state_patch db-maestro_core_db '{"phase":"BLOCKED","last_completed_phase":"NONE","phase_started_epoch":202,"phase_durations":{},"tables_ready":0,"tables_total":0,"last_error":"missing_replica_identity=public.runner_location_p20260806 missing_replica_identity=public.runner_location_p20260807 missing_replica_identity=public.runner_location_p20260808 REFUSED: tables missing replica identity"}'
status="$(status_text)"
assert_contains "$status" '*Blocked*' 'status groups blocked databases'
assert_contains "$status" 'atlas: replica identity missing: public.geo_hood' 'status formats single blocked table'
assert_contains "$status" 'maestro_core_db: replica identity missing: public.runner_location_p20260806, public.runner_location_p20260807, public.runner_location_p20260808' 'status formats multiple blocked tables'
assert_contains "$status" '*Preflight complete*' 'status groups preflight-complete databases'
assert_contains "$status" 'expert_ops' 'status lists preflight-complete database'
assert_not_contains "$status" 'phase=BLOCKED' 'status does not expose raw blocked phase line'
assert_not_contains "$status" 'error=missing_replica_identity' 'status does not expose raw inline error field'

rm -f "$STATE_DIR"/*
export DATABASES_JSON='[{"name":"pulse","source_db":"pulse","target_db":"pulse","publication":"pulse_pub","subscription":"pulse_sub"}]'
state_patch db-pulse '{"phase":"LOAD","last_completed_phase":"SCHEMA","phase_started_epoch":201,"phase_durations":{"PREFLIGHT":1,"SCHEMA":2},"tables_ready":12,"tables_total":72,"last_error":"created slot"}'
target_psql() {
  db="$1"
  shift
  sql="$*"
  [ "$db" = "pulse" ] || fail "status subscription summary queried unexpected db $db"
  if printf '%s' "$sql" | grep -F "select 'enabled='" >/dev/null; then
    printf '%s\n' 'enabled=true'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "group by r.srsubstate" >/dev/null; then
    printf '%s\n' 'd=60' 'f=1' 'r=12'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "r.srsubstate <> 'r'" >/dev/null; then
    printf '%s\n' 'public.stuck_a=d' 'public.stuck_b=d'
    return 0
  fi
  fail "unexpected status subscription summary query: $sql"
}
status="$(status_text)"
assert_contains "$status" 'pulse: phase=LOAD last=SCHEMA tables=12/72' 'status still shows checkpoint progress'
assert_contains "$status" 'subscription=pulse_sub enabled=true states ready=12 data_copy=60 finished_copy=1' 'status summarizes subscription table states'
assert_contains "$status" 'non_ready=public.stuck_a=d,public.stuck_b=d' 'status lists capped non-ready subscription tables'

rm -f "$STATE_DIR"/*
export DATABASES_JSON='[{"name":"ok_db","source_db":"src_ok","target_db":"tgt_ok","publication":"ok_pub","subscription":"ok_sub"},{"name":"bad_db","source_db":"src_bad","target_db":"tgt_bad","publication":"bad_pub","subscription":"bad_sub"}]'
export SELECTED_DBS='ok_db'
selected_keys="$(db_keys | tr '\n' ' ')"
[ "$selected_keys" = "ok_db " ] || fail 'db_keys filters to selected database list'
export SELECTED_DBS='missing_db'
if db_keys >/tmp/selected-missing.out 2>/tmp/selected-missing.err; then
  fail 'db_keys must reject unknown selected databases'
fi
assert_contains "$(cat /tmp/selected-missing.err)" 'unknown selected database: missing_db' 'db_keys reports unknown selected database'
unset SELECTED_DBS

if grep -n 'target_psql "$target_db" -f "$constraints"' "$MODULE_DIR/scripts/replicate.sh" >/tmp/schema-constraints-lines; then
  fail "SCHEMA must not apply post-data constraints before subscription copy_data=true: $(cat /tmp/schema-constraints-lines)"
fi

if ! grep -n 'CREATE SUBSCRIPTION %I CONNECTION %L PUBLICATION %I WITH (copy_data = true' "$MODULE_DIR/scripts/replicate.sh" >/tmp/subscription-copy-lines; then
  fail 'LOAD must let PostgreSQL own the initial data copy with copy_data=true'
fi

if ! grep -n "nspname NOT IN ('pg_catalog','information_schema')" "$MODULE_DIR/scripts/replicate.sh" >/tmp/publish-schema-grant-lines; then
  fail 'PUBLISH must grant replication role access across all non-system source schemas'
fi
if grep -n 'GRANT SELECT ON ALL TABLES IN SCHEMA public TO :"repl_user"' "$MODULE_DIR/scripts/replicate.sh" >/tmp/public-only-grant-lines; then
  fail "PUBLISH must not grant only public schema tables: $(cat /tmp/public-only-grant-lines)"
fi
if ! grep -n 'ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT ON TABLES TO %I' "$MODULE_DIR/scripts/replicate.sh" >/tmp/default-priv-all-schema-lines; then
  fail 'PUBLISH must set default SELECT privileges per non-system schema'
fi

if ! grep -n 'wait_tables_ready "$db_key"' "$MODULE_DIR/scripts/replicate.sh" >/tmp/load-wait-lines; then
  fail 'LOAD must wait for subscription table sync readiness before completing'
fi
if ! grep -n 'load_ready_timeout_seconds:' "$MODULE_DIR/facets.yaml" >/tmp/load-ready-timeout-schema-lines; then
  fail 'facets schema must expose options.load_ready_timeout_seconds'
fi
if ! grep -n 'load_ready_timeout_seconds' "$MODULE_DIR/variables.tf" >/tmp/load-ready-timeout-variable-lines; then
  fail 'variables.tf must expose options.load_ready_timeout_seconds'
fi
if ! grep -n 'LOAD_READY_TIMEOUT_SECONDS=${local.load_ready_timeout_seconds}' "$MODULE_DIR/main.tf" >/tmp/load-ready-timeout-render-lines; then
  fail 'main.tf must render LOAD_READY_TIMEOUT_SECONDS into the runner config'
fi
if ! grep -n 'LOAD_READY_TIMEOUT_SECONDS' "$MODULE_DIR/scripts/replicate.sh" >/tmp/load-ready-timeout-script-lines; then
  fail 'wait_tables_ready must use LOAD_READY_TIMEOUT_SECONDS'
fi

rm -f "$STATE_DIR"/*
export DATABASES_JSON='[{"name":"pulse","source_db":"pulse_src","target_db":"pulse_tgt","publication":"pulse_pub","subscription":"pulse_sub"}]'
source_psql() {
  db="$1"
  shift
  sql="$*"
  if printf '%s' "$sql" | grep -F "relkind in ('r','p')" >/dev/null; then
    printf '%s\n' '76'
    return 0
  fi
  fail "unexpected source_psql call while testing subscription readiness: $db $sql"
}
target_psql() {
  db="$1"
  shift
  sql="$*"
  [ "$db" = "pulse_tgt" ] || fail "subscription readiness queried unexpected target db $db"
  if printf '%s' "$sql" | grep -F "pg_subscription_rel" >/dev/null; then
    printf '%s\n%s\n' '72' '72'
    return 0
  fi
  fail "unexpected target_psql call while testing subscription readiness: $db $sql"
}
if ! all_tables_ready pulse >/tmp/subscription-ready.out 2>/tmp/subscription-ready.err; then
  fail 'subscription readiness must be based on pg_subscription_rel readiness, not source relation count'
fi
assert_contains "$(cat /tmp/subscription-ready.out)" 'tables_ready=72/72' 'subscription readiness prints target subscription progress'

target_psql() {
  db="$1"
  shift
  sql="$*"
  [ "$db" = "pulse_tgt" ] || fail "subscription copy-finished queried unexpected target db $db"
  if printf '%s' "$sql" | grep -F "r.srsubstate in ('f','s','r')" >/dev/null; then
    printf '%s\n%s\n' '72' '72'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "pg_subscription_rel" >/dev/null; then
    printf '%s\n%s\n' '72' '12'
    return 0
  fi
  fail "unexpected target_psql call while testing subscription copy-finished: $db $sql"
}
if ! all_tables_copy_finished pulse >/tmp/subscription-copy-finished.out 2>/tmp/subscription-copy-finished.err; then
  fail 'deferred primary-key LOAD must be allowed to complete when all tables are copy-finished f/s/r'
fi
assert_contains "$(cat /tmp/subscription-copy-finished.out)" 'tables_copy_finished=72/72' 'copy-finished readiness prints target subscription progress'
if all_tables_ready pulse >/tmp/subscription-not-ready.out 2>/tmp/subscription-not-ready.err; then
  fail 'true subscription readiness must still require all tables at r'
fi
assert_contains "$(cat /tmp/subscription-not-ready.out)" 'tables_ready=12/72' 'true readiness still reports only r states'

rm -f "$STATE_DIR"/*
export DATABASES_JSON='[{"name":"pulse","source_db":"pulse_src","target_db":"pulse_tgt","publication":"pulse_pub","subscription":"pulse_sub"}]'
export DEFER_SECONDARY_INDEXES=true
export LOAD_READY_SLEEP_SECONDS=1
export LOAD_READY_TIMEOUT_SECONDS=1
cat > "$WORK_DIR/pulse-post.sql" <<'SQL'
ALTER TABLE ONLY public.done
    ADD CONSTRAINT done_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.copying
    ADD CONSTRAINT copying_pkey PRIMARY KEY (id);
CREATE INDEX done_idx ON public.done USING btree (created_at);
SQL
cat > "$WORK_DIR/pulse-target-relations.txt" <<'EOF'
public.done
public.copying
EOF
incremental_calls="$STATE_DIR/incremental-pk-calls"
pg_dump() {
  fail 'incremental primary-key loader should reuse cached post-data dump in this unit'
}
target_psql() {
  db="$1"
  shift
  sql="$*"
  [ "$db" = "pulse_tgt" ] || fail "incremental PK queried unexpected target db $db"
  if printf '%s' "$sql" | grep -F "n.nspname || '.' || c.relname" >/dev/null; then
    printf '%s\n' 'public.done'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "srsubstate in ('f','s','r')" >/dev/null; then
    printf '%s\n%s\n' '2' '1'
    return 0
  fi
  if [ "${1:-}" = "-f" ]; then
    cat "$2" >> "$incremental_calls"
    return 0
  fi
  fail "unexpected target_psql call while testing incremental PK load: $db $sql"
}
if wait_tables_copy_finished_with_incremental_primary pulse >/tmp/incremental-pk.out 2>/tmp/incremental-pk.err; then
  fail 'incremental PK wait should still time out when not all copies are finished'
fi
assert_contains "$(cat /tmp/incremental-pk.out)" 'applying_primary_keys_for_copy_finished_tables count=1' 'incremental PK wait applies keys for finished tables'
assert_contains "$(cat "$incremental_calls")" 'ADD CONSTRAINT done_pkey PRIMARY KEY' 'incremental PK wait applies finished table primary key'
assert_not_contains "$(cat "$incremental_calls")" 'copying_pkey' 'incremental PK wait does not apply unfinished table primary key'
assert_not_contains "$(cat "$incremental_calls")" 'CREATE INDEX done_idx' 'incremental PK wait does not apply secondary indexes'
export LOAD_READY_SLEEP_SECONDS=10
export LOAD_READY_TIMEOUT_SECONDS=600

if ! grep -n 'split_post_data_sql "$db_key" "$post" "$primary" "$secondary" "$target_relations"' "$MODULE_DIR/scripts/replicate.sh" >/tmp/index-split-lines; then
  fail 'INDEX must split post-data SQL after subscription tables are ready'
fi

if ! grep -n 'target_psql "$target_db" -f "$primary"' "$MODULE_DIR/scripts/replicate.sh" >/tmp/index-primary-lines; then
  fail 'INDEX must apply primary keys first after subscription initial copy is ready'
fi

if ! grep -n 'wait_tables_ready "$db_key"' "$MODULE_DIR/scripts/replicate.sh" >/tmp/index-wait-after-primary-lines; then
  fail 'INDEX must wait for true r readiness after primary keys before applying secondary post-data'
fi

if ! grep -n 'target_psql "$target_db" -f "$secondary"' "$MODULE_DIR/scripts/replicate.sh" >/tmp/index-secondary-lines; then
  fail 'INDEX must apply secondary post-data after primary keys'
fi

if ! grep -n 'cutover)' "$MODULE_DIR/scripts/replicate.sh" >/tmp/cutover-mode-lines; then
  fail 'main must expose a cutover mode'
fi

if ! grep -n 'cutover = {' "$MODULE_DIR/actions.tf" >/tmp/cutover-action-lines; then
  fail 'actions must expose cutover'
fi
if ! grep -n 'cutover-hold = {' "$MODULE_DIR/actions.tf" >/tmp/cutover-hold-action-lines; then
  fail 'actions must expose cutover-hold'
fi
if ! grep -n 'resume = {' "$MODULE_DIR/actions.tf" >/tmp/resume-action-lines; then
  fail 'actions must expose resume'
fi
if ! grep -n 'finalize-cutover = {' "$MODULE_DIR/actions.tf" >/tmp/finalize-cutover-action-lines; then
  fail 'actions must expose finalize-cutover'
fi
if grep -n 'cutover-sync-sequences = {' "$MODULE_DIR/actions.tf" >/tmp/cutover-sync-action-lines; then
  fail 'actions must not expose cutover-sync-sequences'
fi
cutover_block="$(awk '/cutover\)/,/;;/' "$MODULE_DIR/scripts/replicate.sh")"
assert_contains "$cutover_block" 'cutover_hold_db "$db_key"' 'cutover must hold replication instead of dropping it'
assert_not_contains "$cutover_block" 'stop_db "$db_key"' 'cutover must not use stop/drop cleanup'
if ! grep -n 'resume)' "$MODULE_DIR/scripts/replicate.sh" >/tmp/resume-mode-lines; then
  fail 'main must expose resume mode'
fi
if ! grep -n 'finalize-cutover)' "$MODULE_DIR/scripts/replicate.sh" >/tmp/finalize-mode-lines; then
  fail 'main must expose finalize-cutover mode'
fi
if ! grep -n 'discover-roles = {' "$MODULE_DIR/actions.tf" >/tmp/discover-roles-action-lines; then
  fail 'actions must expose discover-roles'
fi
if ! grep -n 'debug-shell = {' "$MODULE_DIR/actions.tf" >/tmp/debug-shell-action-lines; then
  fail 'actions must expose debug-shell'
fi
if ! grep -n 'DEBUG_TTL_SECONDS' "$MODULE_DIR/actions.tf" >/tmp/debug-shell-ttl-lines; then
  fail 'debug-shell action must expose DEBUG_TTL_SECONDS'
fi
if ! grep -n '\"/spec/template/spec/containers/0/command\"' "$MODULE_DIR/actions.tf" >/tmp/debug-shell-command-patch-lines; then
  fail 'debug-shell action must patch container command instead of running the driver'
fi
if ! grep -n '\"/spec/template/spec/containers/0/args\"' "$MODULE_DIR/actions.tf" >/tmp/debug-shell-args-patch-lines; then
  fail 'debug-shell action must patch container args to sleep'
fi
if ! grep -n '\"/spec/template/spec/activeDeadlineSeconds\"' "$MODULE_DIR/actions.tf" >/tmp/debug-shell-deadline-patch-lines; then
  fail 'debug-shell action must set activeDeadlineSeconds'
fi
if ! grep -n 'discover-roles)' "$MODULE_DIR/scripts/replicate.sh" >/tmp/discover-roles-mode-lines; then
  fail 'main must expose discover-roles mode'
fi

rm -f "$STATE_DIR"/*
publish_calls="$STATE_DIR/publish-calls"
export DATABASES_JSON='[{"name":"maestro_core_db","source_db":"maestro_core_db","target_db":"maestro_core_db","publication":"commonpg_maestro_core_pub","subscription":"commonpg_maestro_core_sub","exclude_schemas":["pglogical","partman"],"exclude_tables":["public.databasechangelog"]}]'
source_psql() {
  db="$1"
  shift
  printf 'source:%s:%s\n' "$db" "$*" >> "$publish_calls"
  cat >> "$publish_calls"
  if printf '%s' "$*" | grep -F "from pg_publication_tables" >/dev/null; then
    printf '%s\n' '2'
  fi
}
source_repl_psql() {
  db="$1"
  shift
  printf 'source-repl:%s:%s\n' "$db" "$*" >> "$publish_calls"
  cat >> "$publish_calls"
  printf '%s\n' 'statement_timeout=0' 'idle_in_transaction_session_timeout=0' 'lock_timeout=0'
}
publish_db maestro_core_db >/tmp/publish-filtered.out 2>/tmp/publish-filtered.err
publish_sql="$(cat "$publish_calls")"
assert_contains "$publish_sql" 'jsonb_array_elements_text' 'publication builder reads schema excludes from database config'
assert_contains "$publish_sql" '-v exclude_tables=["public.databasechangelog"]' 'publication builder reads table excludes from database config'
assert_contains "$publish_sql" "d.deptype = 'e'" 'publication builder excludes extension-owned tables'
assert_contains "$publish_sql" 't.table_fqname = n.nspname || '\''.'\'' || c.relname' 'publication builder excludes configured tables'
assert_contains "$publish_sql" "c.relkind = 'r'" 'publication builder publishes leaf tables only, not partitioned parents'
assert_contains "$publish_sql" "n.nspname !~ '^pg_temp_'" 'publication builder excludes transient PostgreSQL temp schemas'
assert_contains "$publish_sql" "n.nspname !~ '^pg_toast_temp_'" 'publication builder excludes transient PostgreSQL temp toast schemas'
assert_not_contains "$publish_sql" "c.relkind IN ('r','p')" 'publication builder must not publish partitioned parents because child excludes would be bypassed'
assert_contains "$publish_sql" 'CREATE PUBLICATION %I FOR TABLE %s' 'publication builder creates explicit table publication'
assert_not_contains "$publish_sql" 'FOR ALL TABLES' 'publication builder must not use FOR ALL TABLES'
assert_contains "$publish_sql" 'DROP PUBLICATION IF EXISTS %I' 'publication builder can convert old FOR ALL TABLES publications'
assert_contains "$publish_sql" 'ALTER ROLE %I SET statement_timeout = 0' 'publish sets source replication role statement_timeout to zero'
assert_contains "$publish_sql" 'ALTER ROLE %I SET lock_timeout = 0' 'publish sets source replication role lock_timeout to zero'
assert_contains "$publish_sql" 'ALTER ROLE %I SET idle_in_transaction_session_timeout = 0' 'publish sets source replication role idle timeout to zero'
assert_contains "$publish_sql" 'source-repl:maestro_core_db' 'publish verifies effective source replication user settings after creating role'
assert_contains "$(cat /tmp/publish-filtered.out)" 'source_repl_setting statement_timeout=0' 'publish prints verified source replication user settings'

rm -f "$STATE_DIR"/*
publish_verify_calls="$STATE_DIR/publish-verify-calls"
export DATABASES_JSON='[{"name":"payouts_db","source_db":"payouts_db","target_db":"payouts_db","publication":"payouts_prod_pub","subscription":"payouts_prod_sub"}]'
source_psql() {
  db="$1"
  shift
  printf 'source:%s:%s\n' "$db" "$*" >> "$publish_verify_calls"
  cat >> "$publish_verify_calls"
  if printf '%s' "$*" | grep -F "from pg_publication_tables" >/dev/null; then
    printf '%s\n' '0'
  fi
}
source_repl_psql() {
  printf '%s\n' 'statement_timeout=0' 'idle_in_transaction_session_timeout=0' 'lock_timeout=0'
}
if publish_db payouts_db >/tmp/publish-verify.out 2>/tmp/publish-verify.err; then
  fail 'publish must fail when the configured publication has no tables after creation'
fi
assert_contains "$(cat /tmp/publish-verify.err)" 'REFUSED: publication payouts_prod_pub has no tables' 'publish post-check reports missing publication tables'

rm -f "$STATE_DIR"/*
preflight_calls="$STATE_DIR/preflight-calls"
export DATABASES_JSON='[{"name":"maestro_core_db","source_db":"maestro_core_db","target_db":"maestro_core_db","publication":"commonpg_maestro_core_pub","subscription":"commonpg_maestro_core_sub","exclude_schemas":["pglogical","partman"],"exclude_tables":["public.databasechangelog"]}]'
export TARGET_DISK_GB=0
export TARGET_AUTORESIZE_LIMIT_GB=0
source_psql() {
  db="$1"
  shift
  printf 'source:%s:%s\n' "$db" "$*" >> "$preflight_calls"
  cat >> "$preflight_calls"
  case "$*" in
    *pg_database_size*) printf '%s\n' '1' ;;
    *) printf '' ;;
  esac
}
source_auth_psql() {
  db="$1"
  shift
  source_psql "$(source_auth_db_for "$db")" "$@"
}
target_psql() {
  db="$1"
  shift
  printf 'target:%s:%s\n' "$db" "$*" >> "$preflight_calls"
  cat >> "$preflight_calls"
  printf ''
}
source_repl_psql() {
  db="$1"
  shift
  printf 'source-repl:%s:%s\n' "$db" "$*" >> "$preflight_calls"
  cat >> "$preflight_calls"
  fail 'preflight must not connect as source replication user'
}
preflight_db maestro_core_db >/tmp/preflight-filtered.out 2>/tmp/preflight-filtered.err
preflight_sql="$(cat "$preflight_calls")"
assert_contains "$preflight_sql" 'jsonb_array_elements_text' 'preflight replica identity audit reads schema excludes from database config'
assert_contains "$preflight_sql" '-v exclude_tables=["public.databasechangelog"]' 'preflight replica identity audit reads table excludes from database config'
assert_contains "$preflight_sql" "d.deptype = 'e'" 'preflight replica identity audit excludes extension-owned tables'
assert_contains "$preflight_sql" 't.table_fqname = n.nspname || '\''.'\'' || c.relname' 'preflight replica identity audit excludes configured tables'
assert_contains "$preflight_sql" "c.relkind = 'r'" 'preflight replica identity audit only checks regular tables for replica identity'
assert_contains "$preflight_sql" "n.nspname !~ '^pg_temp_'" 'preflight excludes transient PostgreSQL temp schemas'
assert_contains "$preflight_sql" "n.nspname !~ '^pg_toast_temp_'" 'preflight excludes transient PostgreSQL temp toast schemas'
assert_not_contains "$preflight_sql" 'source-repl:maestro_core_db' 'preflight does not require source replication user before publish'

rm -f "$STATE_DIR"/*
preflight_timeout_calls="$STATE_DIR/preflight-timeout-calls"
export DATABASES_JSON='[{"name":"maestro_core_db","source_db":"maestro_core_db","target_db":"maestro_core_db","publication":"commonpg_maestro_core_pub","subscription":"commonpg_maestro_core_sub"}]'
export TARGET_DISK_GB=0
export TARGET_AUTORESIZE_LIMIT_GB=0
source_psql() {
  db="$1"
  shift
  printf 'source:%s:%s\n' "$db" "$*" >> "$preflight_timeout_calls"
  cat >> "$preflight_timeout_calls"
  case "$*" in
    *pg_database_size*) printf '%s\n' '1' ;;
    *) printf '' ;;
  esac
}
source_auth_psql() {
  db="$1"
  shift
  source_psql "$(source_auth_db_for "$db")" "$@"
}
target_psql() {
  db="$1"
  shift
  printf 'target:%s:%s\n' "$db" "$*" >> "$preflight_timeout_calls"
  cat >> "$preflight_timeout_calls"
  printf ''
}
source_repl_psql() {
  db="$1"
  shift
  printf 'source-repl:%s:%s\n' "$db" "$*" >> "$preflight_timeout_calls"
  cat >> "$preflight_timeout_calls"
  fail 'preflight must not check source replication user timeouts'
}
preflight_db maestro_core_db >/tmp/preflight-timeout.out 2>/tmp/preflight-timeout.err
assert_not_contains "$(cat "$preflight_timeout_calls")" 'source-repl:maestro_core_db' 'preflight does not fail fresh sources when replication user is absent'

cat > "$WORK_DIR/post-data.sql" <<'SQL'
ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);
CREATE INDEX orders_created_at_idx ON public.orders USING btree (created_at);
CREATE UNIQUE INDEX orders_external_id_idx ON public.orders USING btree (external_id);
CREATE INDEX break_slot_assignment_idx ON ONLY public.break_slot_assignment USING btree (id);
CREATE STATISTICS public.stats_job_filter ON status, created_at FROM public.orders;
ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id);
ALTER TABLE public.pricing_on_demand_surge
    ADD CONSTRAINT pricing_on_demand_surge_hood_id_fkey FOREIGN KEY (hood_id) REFERENCES public.geo_hood(id);
CREATE INDEX runner_location_p20260818_idx ON public.runner_location_p20260818 USING btree (id);
ALTER INDEX public.rl_part_runner_created_idx ATTACH PARTITION public.runner_location_p20260818_idx;
ALTER TABLE ONLY partman.template_public_runner_location_partitioned
    ADD CONSTRAINT template_public_runner_location_partitioned_pkey PRIMARY KEY (id);
CREATE TRIGGER trg_audit_geo_hood BEFORE INSERT OR UPDATE ON public.geo_hood FOR EACH ROW EXECUTE FUNCTION public.audit_row();
CREATE PUBLICATION commonpg_merch_pub FOR TABLE public.orders;
ALTER PUBLICATION commonpg_merch_pub ADD TABLE ONLY public.order_items;
SQL
: > "$WORK_DIR/primary.sql"
: > "$WORK_DIR/secondary.sql"
cat > "$WORK_DIR/target-relations.txt" <<'EOF'
public.orders
public.order_items
public.break_slot_assignment
public.rl_part_runner_created_idx
public.geo_hood
public.pricing_on_demand_surge
EOF
export DATABASES_JSON='[{"name":"maestro_core_db","source_db":"maestro_core_db","target_db":"maestro_core_db","publication":"commonpg_maestro_core_pub","subscription":"commonpg_maestro_core_sub","exclude_schemas":["partman"],"exclude_tables":["public.runner_location_p20260818"]}]'
split_post_data_sql maestro_core_db "$WORK_DIR/post-data.sql" "$WORK_DIR/primary.sql" "$WORK_DIR/secondary.sql" "$WORK_DIR/target-relations.txt"
assert_contains "$(cat "$WORK_DIR/primary.sql")" 'ADD CONSTRAINT orders_pkey PRIMARY KEY' 'post-data split puts primary key constraints first'
assert_contains "$(cat "$WORK_DIR/primary.sql")" 'IF to_regclass(' 'post-data split wraps primary constraints idempotently'
assert_not_contains "$(cat "$WORK_DIR/primary.sql")" 'orders_created_at_idx' 'post-data split excludes secondary indexes from primary pass'
assert_not_contains "$(cat "$WORK_DIR/primary.sql")" 'template_public_runner_location_partitioned' 'post-data split excludes primary constraints for excluded schemas'
assert_contains "$(cat "$WORK_DIR/secondary.sql")" 'CREATE INDEX CONCURRENTLY IF NOT EXISTS orders_created_at_idx' 'post-data split makes secondary index concurrent and idempotent'
assert_contains "$(cat "$WORK_DIR/secondary.sql")" 'CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS orders_external_id_idx' 'post-data split makes secondary unique index concurrent and idempotent'
assert_contains "$(cat "$WORK_DIR/secondary.sql")" 'CREATE INDEX IF NOT EXISTS break_slot_assignment_idx ON ONLY public.break_slot_assignment' 'post-data split does not create partitioned parent indexes concurrently'
assert_contains "$(cat "$WORK_DIR/secondary.sql")" 'CREATE STATISTICS IF NOT EXISTS public.stats_job_filter' 'post-data split makes extended statistics idempotent'
assert_not_contains "$(cat "$WORK_DIR/secondary.sql")" 'CREATE INDEX CONCURRENTLY IF NOT EXISTS break_slot_assignment_idx ON ONLY' 'partitioned parent index must not be concurrent'
assert_not_contains "$(cat "$WORK_DIR/secondary.sql")" 'runner_location_p20260818' 'post-data split excludes indexes for excluded tables'
assert_not_contains "$(cat "$WORK_DIR/secondary.sql")" 'ATTACH PARTITION public.runner_location_p20260818_idx' 'post-data split excludes index attachment for missing target partition indexes'
assert_not_contains "$(cat "$WORK_DIR/secondary.sql")" 'CREATE PUBLICATION' 'post-data split excludes source publication DDL'
assert_not_contains "$(cat "$WORK_DIR/secondary.sql")" 'ALTER PUBLICATION' 'post-data split excludes publication membership DDL'
assert_contains "$(cat "$WORK_DIR/secondary.sql")" 'ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY' 'post-data split leaves foreign keys in secondary pass'
assert_contains "$(cat "$WORK_DIR/secondary.sql")" 'pricing_on_demand_surge_hood_id_fkey' 'post-data split leaves non-excluded foreign keys in secondary pass'
assert_contains "$(cat "$WORK_DIR/secondary.sql")" 'IF to_regclass(' 'post-data split wraps secondary constraints idempotently'
assert_contains "$(cat "$WORK_DIR/secondary.sql")" 'tgname = '\''trg_audit_geo_hood'\''' 'post-data split wraps triggers idempotently'
assert_contains "$(cat "$WORK_DIR/secondary.sql")" 'CREATE TRIGGER trg_audit_geo_hood' 'post-data split preserves trigger DDL inside idempotent wrapper'

cat > "$WORK_DIR/copy-finished-relations.txt" <<'EOF'
public.orders
EOF
: > "$WORK_DIR/primary.sql"
: > "$WORK_DIR/secondary.sql"
split_post_data_sql maestro_core_db "$WORK_DIR/post-data.sql" "$WORK_DIR/primary.sql" "$WORK_DIR/secondary.sql" "$WORK_DIR/target-relations.txt" "$WORK_DIR/copy-finished-relations.txt"
assert_contains "$(cat "$WORK_DIR/primary.sql")" 'ADD CONSTRAINT orders_pkey PRIMARY KEY' 'copy-finished split includes PK for finished tables'
assert_not_contains "$(cat "$WORK_DIR/primary.sql")" 'template_public_runner_location_partitioned_pkey' 'copy-finished split excludes PK for unfinished or excluded tables'
assert_contains "$(cat "$WORK_DIR/secondary.sql")" 'CREATE INDEX CONCURRENTLY IF NOT EXISTS orders_created_at_idx' 'copy-finished split leaves secondary DDL separate'

FOREIGN_KEY_VALIDATION_MODE=not_valid
: > "$WORK_DIR/primary.sql"
: > "$WORK_DIR/secondary.sql"
split_post_data_sql maestro_core_db "$WORK_DIR/post-data.sql" "$WORK_DIR/primary.sql" "$WORK_DIR/secondary.sql" "$WORK_DIR/target-relations.txt"
assert_contains "$(cat "$WORK_DIR/secondary.sql")" 'FOREIGN KEY (order_id) REFERENCES public.orders(id) NOT VALID;' 'not_valid FK mode replays foreign keys without validating existing rows'
assert_not_contains "$(cat "$WORK_DIR/primary.sql")" 'NOT VALID' 'not_valid FK mode does not alter primary key constraints'
FOREIGN_KEY_VALIDATION_MODE=strict
export DATABASES_JSON='[{"name":"citadel_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub"}]'

export DATABASES_JSON='[{"name":"maestro_core_db","source_db":"maestro_core_db","target_db":"maestro_core_db","publication":"commonpg_maestro_core_pub","subscription":"commonpg_maestro_core_sub","exclude_foreign_keys":["public.pricing_on_demand_surge.pricing_on_demand_surge_hood_id_fkey"]}]'
: > "$WORK_DIR/primary.sql"
: > "$WORK_DIR/secondary.sql"
split_post_data_sql maestro_core_db "$WORK_DIR/post-data.sql" "$WORK_DIR/primary.sql" "$WORK_DIR/secondary.sql" "$WORK_DIR/target-relations.txt" 2>"$WORK_DIR/fk-skip.err"
assert_not_contains "$(cat "$WORK_DIR/secondary.sql")" 'pricing_on_demand_surge_hood_id_fkey' 'post-data split skips explicitly excluded foreign key'
assert_contains "$(cat "$WORK_DIR/secondary.sql")" 'order_items_order_id_fkey' 'post-data split keeps unrelated foreign keys when one FK is excluded'
assert_contains "$(cat "$WORK_DIR/fk-skip.err")" 'WARNING: skipping excluded foreign key public.pricing_on_demand_surge.pricing_on_demand_surge_hood_id_fkey' 'post-data split logs explicit foreign key skip'

state_json="$(build_db_state maestro_core_db INDEX LOAD "" 0 0 false)"
skipped_fk="$(printf '%s' "$state_json" | jq -c '.skipped_foreign_keys')"
assert_contains "$skipped_fk" 'public.pricing_on_demand_surge.pricing_on_demand_surge_hood_id_fkey' 'state records configured skipped foreign keys'

export DATABASES_JSON='[{"name":"citadel_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub"}]'

rm -f "$STATE_DIR"/*
export DATABASES_JSON='[{"name":"citadel_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub"}]'
sync_calls="$STATE_DIR/sync-calls"
source_psql() {
  db="$1"
  shift
  sql="$*"
  if printf '%s' "$sql" | grep -F "relkind in ('r','p')" >/dev/null; then
    printf '%s\n' '1'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "confirmed_flush_lsn" >/dev/null; then
    printf '%s\n' '0'
    return 0
  fi
  printf 'source:%s:%s\n' "$db" "$sql" >> "$sync_calls"
  cat >> "$sync_calls"
}
target_psql() {
  db="$1"
  shift
  sql="$*"
  if printf '%s' "$sql" | grep -F "select coalesce(subenabled::text" >/dev/null; then
    printf '%s\n' 'true'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "pg_subscription_rel" >/dev/null; then
    printf '%s\n%s\n' '1' '1'
    return 0
  fi
  printf 'target:%s:%s\n' "$db" "$sql" >> "$sync_calls"
  cat >> "$sync_calls"
}

ALLOW_MUTATION=true
sync_sequences_db citadel_db >/tmp/sync-forward.out 2>/tmp/sync-forward.err
assert_contains "$(cat "$sync_calls")" 'target:tgt:' 'forward sequence sync runs on target database'
assert_not_contains "$(cat "$sync_calls")" 'source:src:' 'forward sequence sync does not write source database'
assert_contains "$(cat "$sync_calls")" 'pg_depend d' 'sequence sync discovers owned sequences'
assert_contains "$(cat "$sync_calls")" 'CREATE TEMP TABLE owned_sequences' 'sequence sync materializes owned sequence discovery for reuse'
assert_contains "$(cat "$sync_calls")" 'setval(' 'sequence sync emits setval'
assert_contains "$(cat "$sync_calls")" 'column_type IN' 'sequence sync only advances integer-owned sequences'
assert_contains "$(cat "$sync_calls")" 'sequence_skip_non_integer' 'sequence sync reports skipped non-integer owned sequences'

: > "$sync_calls"
ALLOW_MUTATION=false
if sync_sequences_db citadel_db >/tmp/sync-reverse.out 2>/tmp/sync-reverse.err; then
  fail 'sequence sync must be refused when mutations are disabled'
fi
assert_contains "$(cat /tmp/sync-reverse.err)" 'REFUSED: mutating replication actions are disabled by options.allow_mutation=false' 'mutation-disabled refusal is explicit'
if [ -s "$sync_calls" ]; then
  fail "mutation-disabled sequence sync must not write source or target: $(cat "$sync_calls")"
fi
ALLOW_MUTATION=true

rm -f "$STATE_DIR"/*
export DATABASES_JSON='[{"name":"citadel_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub"}]'
cutover_calls="$STATE_DIR/cutover-calls"
state_patch db-citadel_db '{"phase":"STEADY","last_completed_phase":"STEADY","phase_started_epoch":200,"phase_durations":{},"tables_ready":1,"tables_total":1,"last_error":""}'
source_psql() {
  db="$1"
  shift
  sql="$*"
  if printf '%s' "$sql" | grep -F "confirmed_flush_lsn" >/dev/null; then
    printf '%s\n' '0'
    return 0
  fi
  printf 'source:%s:%s\n' "$db" "$sql" >> "$cutover_calls"
  cat >> "$cutover_calls"
}
target_psql() {
  db="$1"
  shift
  sql="$*"
  if printf '%s' "$sql" | grep -F "select coalesce(subenabled::text" >/dev/null; then
    printf '%s\n' 'true'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "pg_subscription_rel" >/dev/null; then
    printf '%s\n%s\n' '1' '1'
    return 0
  fi
  printf 'target:%s:%s\n' "$db" "$sql" >> "$cutover_calls"
  cat >> "$cutover_calls"
}
cutover_hold_db citadel_db >/tmp/cutover-hold.out 2>/tmp/cutover-hold.err
assert_contains "$(cat "$cutover_calls")" 'setval(' 'cutover-hold syncs target sequences before disabling'
assert_contains "$(cat "$cutover_calls")" 'ALTER SUBSCRIPTION %I DISABLE' 'cutover-hold disables the subscription'
assert_not_contains "$(cat "$cutover_calls")" 'DROP SUBSCRIPTION' 'cutover-hold does not drop the subscription'
assert_not_contains "$(cat "$cutover_calls")" 'pg_drop_replication_slot' 'cutover-hold does not drop the source slot'
held_state="$(cat "$STATE_DIR/db-citadel_db")"
[ "$(printf '%s' "$held_state" | jq -r '.phase')" = "CUTOVER_HELD" ] || fail 'cutover-hold records CUTOVER_HELD phase'
[ "$(printf '%s' "$held_state" | jq -r '.last_completed_phase')" = "STEADY" ] || fail 'cutover-hold preserves STEADY as last completed phase'

: > "$cutover_calls"
target_psql() {
  db="$1"
  shift
  sql="$*"
  if printf '%s' "$sql" | grep -F "select coalesce(subenabled::text" >/dev/null; then
    printf '%s\n' 'false'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "pg_subscription_rel" >/dev/null; then
    printf '%s\n%s\n' '1' '1'
    return 0
  fi
  printf 'target:%s:%s\n' "$db" "$sql" >> "$cutover_calls"
  cat >> "$cutover_calls"
}
unset RESUME_CONFIRM_NO_TARGET_WRITES || true
if resume_db citadel_db >/tmp/resume-unconfirmed.out 2>/tmp/resume-unconfirmed.err; then
  fail 'resume must require explicit no-target-writes confirmation'
fi
assert_contains "$(cat /tmp/resume-unconfirmed.err)" 'REFUSED: resume requires RESUME_CONFIRM_NO_TARGET_WRITES=true' 'resume refusal explains target write guard'
export RESUME_CONFIRM_NO_TARGET_WRITES=true
resume_db citadel_db >/tmp/resume.out 2>/tmp/resume.err
assert_contains "$(cat "$cutover_calls")" 'ALTER SUBSCRIPTION %I ENABLE' 'resume re-enables the disabled subscription'
resumed_state="$(cat "$STATE_DIR/db-citadel_db")"
[ "$(printf '%s' "$resumed_state" | jq -r '.phase')" = "STEADY" ] || fail 'resume returns state to STEADY'
[ "$(printf '%s' "$resumed_state" | jq -r '.last_completed_phase')" = "STEADY" ] || fail 'resume preserves STEADY completion'

state_patch db-citadel_db "$held_state"
: > "$cutover_calls"
finalize_cutover_db citadel_db >/tmp/finalize-cutover.out 2>/tmp/finalize-cutover.err
assert_contains "$(cat "$cutover_calls")" 'DROP SUBSCRIPTION %I' 'finalize-cutover drops subscription'
assert_contains "$(cat "$cutover_calls")" 'pg_drop_replication_slot' 'finalize-cutover cleans source slot'
final_state="$(cat "$STATE_DIR/db-citadel_db")"
[ "$(printf '%s' "$final_state" | jq -r '.phase')" = "CUTOVER_FINALIZED" ] || fail 'finalize-cutover records CUTOVER_FINALIZED phase'
unset RESUME_CONFIRM_NO_TARGET_WRITES

preflight_db() {
  db_key="$1"
  echo "preflight $db_key"
  if [ "$db_key" = "bad_db" ]; then
    echo "missing_replica_identity=public.no_pk" >&2
    echo "REFUSED: tables missing replica identity" >&2
    return 1
  fi
}

export DATABASES_JSON='[{"name":"ok_db","source_db":"src_ok","target_db":"tgt_ok","publication":"ok_pub","subscription":"ok_sub"},{"name":"bad_db","source_db":"src_bad","target_db":"tgt_bad","publication":"bad_pub","subscription":"bad_sub"}]'
slack_update() {
  echo "slack_update" >> "$STATE_DIR/slack-calls"
}

if run_preflight_only >/tmp/preflight-only.out 2>/tmp/preflight-only.err; then
  fail 'preflight-only must return non-zero when any database fails'
fi
ok_state="$(cat "$STATE_DIR/db-ok_db")"
bad_state="$(cat "$STATE_DIR/db-bad_db")"
[ "$(printf '%s' "$ok_state" | jq -r '.phase')" = "PREFLIGHT" ] || fail 'preflight-only records successful preflight phase'
[ "$(printf '%s' "$ok_state" | jq -r '.last_completed_phase')" = "PREFLIGHT" ] || fail 'preflight-only records successful preflight completion'
[ "$(printf '%s' "$bad_state" | jq -r '.phase')" = "BLOCKED" ] || fail 'preflight-only records failed database as blocked'
bad_error="$(printf '%s' "$bad_state" | jq -r '.last_error')"
assert_contains "$bad_error" "missing_replica_identity=public.no_pk" 'preflight-only stores missing replica identity detail'
assert_contains "$bad_error" "REFUSED: tables missing replica identity" 'preflight-only stores refusal detail'
[ "$(cat "$STATE_DIR/slack-calls")" = "slack_update" ] || fail 'preflight-only updates Slack once at end'

rm -f "$STATE_DIR"/*
discover_calls="$STATE_DIR/discover-calls"
export DATABASES_JSON='[{"name":"app_db","source_db":"src_app","target_db":"tgt_app","publication":"app_pub","subscription":"app_sub"},{"name":"empty_db","source_db":"src_empty","target_db":"tgt_empty","publication":"empty_pub","subscription":"empty_sub"}]'
source_psql() {
  db="$1"
  shift
  printf 'source:%s:%s\n' "$db" "$*" >> "$discover_calls"
  case "$db" in
    src_app)
      printf '%s\n' app_owner app_user '"report-user"' postgres pg_monitor public source_repl app_owner - 'unknown (OID=0)'
      ;;
    src_empty)
      printf '%s\n' '"report-user"' rdsadmin pg_signal_backend
      ;;
  esac
}
target_psql() {
  fail 'discover-roles must not touch target'
}
discover_roles >/tmp/discover-roles.out 2>/tmp/discover-roles.err
assert_contains "$(cat /tmp/discover-roles.out)" 'target:' 'discover-roles prints target block'
assert_contains "$(cat /tmp/discover-roles.out)" 'login_roles:' 'discover-roles prints login_roles key'
assert_contains "$(cat /tmp/discover-roles.out)" '    - "app_owner"' 'discover-roles includes source object owner'
assert_contains "$(cat /tmp/discover-roles.out)" '    - "app_user"' 'discover-roles includes ACL grantee'
assert_contains "$(cat /tmp/discover-roles.out)" '    - "report-user"' 'discover-roles deduplicates and normalizes quoted roles across DBs'
assert_not_contains "$(cat /tmp/discover-roles.out)" '    - "-"' 'discover-roles excludes invalid dash placeholder'
assert_not_contains "$(cat /tmp/discover-roles.out)" 'unknown (OID=0)' 'discover-roles excludes public grantee OID 0 placeholder'
assert_not_contains "$(cat /tmp/discover-roles.out)" 'postgres' 'discover-roles excludes postgres'
assert_not_contains "$(cat /tmp/discover-roles.out)" 'pg_monitor' 'discover-roles excludes pg_* roles'
assert_not_contains "$(cat /tmp/discover-roles.out)" 'rdsadmin' 'discover-roles excludes rdsadmin'
assert_not_contains "$(cat /tmp/discover-roles.out)" 'public' 'discover-roles excludes public pseudo-role'
assert_not_contains "$(cat /tmp/discover-roles.out)" 'migration_repl' 'discover-roles excludes configured replication user'
assert_contains "$(cat "$discover_calls")" 'source:src_app:' 'discover-roles reads first source db'
assert_contains "$(cat "$discover_calls")" 'source:src_empty:' 'discover-roles reads second source db'
assert_contains "$(cat "$discover_calls")" "n.nspname !~ '^pg_temp_'" 'discover-roles excludes transient PostgreSQL temp schemas'
assert_contains "$(cat "$discover_calls")" "n.nspname !~ '^pg_toast_temp_'" 'discover-roles excludes transient PostgreSQL temp toast schemas'

if ! grep -n 'match-grants = {' "$MODULE_DIR/actions.tf" >/tmp/match-grants-action-lines; then
  fail 'actions must expose match-grants'
fi
if ! grep -n 'match-grants)' "$MODULE_DIR/scripts/replicate.sh" >/tmp/match-grants-mode-lines; then
  fail 'main must expose match-grants mode'
fi
if ! grep -n 'match-grants-dryrun = {' "$MODULE_DIR/actions.tf" >/tmp/match-grants-dryrun-action-lines; then
  fail 'actions must expose match-grants-dryrun'
fi
if ! grep -n 'match-grants-dryrun)' "$MODULE_DIR/scripts/replicate.sh" >/tmp/match-grants-dryrun-mode-lines; then
  fail 'main must expose match-grants-dryrun mode'
fi
cutover_hold_function="$(awk '/^cutover_hold_db\(\)/,/^resume_db\(\)/' "$MODULE_DIR/scripts/replicate.sh")"
assert_contains "$cutover_hold_function" 'match_grants_db "$db_key"' 'cutover-hold must match target grants before disabling replication'

rm -f "$STATE_DIR"/*
grant_calls="$STATE_DIR/grant-calls"
export DATABASES_JSON='[{"name":"maestro_core_db","source_db":"src_maestro","target_db":"tgt_maestro","publication":"maestro_pub","subscription":"maestro_sub"}]'
source_psql() {
  db="$1"
  shift
  input="$(cat)"
  printf 'source:%s:%s %s\n' "$db" "$*" "$input" >> "$grant_calls"
  cat <<'OUT'
prod_app_role		schema:public	GRANT USAGE ON SCHEMA public TO prod_app_role;
prod_app_role		rel:public.orders	GRANT SELECT,INSERT ON TABLE public.orders TO prod_app_role;
prod_app_role		rel:public.orders_id_seq	GRANT USAGE,SELECT ON SEQUENCE public.orders_id_seq TO prod_app_role;
rds_superuser		rel:public.orders	GRANT SELECT ON TABLE public.orders TO rds_superuser;
prod_app_role	prod_customer_app_user	membership:prod_app_role:prod_customer_app_user	GRANT prod_app_role TO prod_customer_app_user;
missing_role		rel:public.orders	GRANT SELECT ON TABLE public.orders TO missing_role;
prod_app_role		rel:public.excluded_source_only	GRANT SELECT ON TABLE public.excluded_source_only TO prod_app_role;
OUT
}
target_psql() {
  db="$1"
  shift
  sql="$*"
  case "$sql" in
    *-At\ * | *-At)
      sql="$sql $(cat)"
      ;;
  esac
  if printf '%s' "$sql" | grep -F 'SELECT rolname FROM pg_roles' >/dev/null; then
    printf '%s\n' prod_app_role prod_customer_app_user postgres
    return 0
  fi
  if printf '%s' "$sql" | grep -F 'grant_object_key' >/dev/null; then
    printf '%s\n' schema:public rel:public.orders rel:public.orders_id_seq
    return 0
  fi
  if [ "${1:-}" = "-f" ]; then
    printf 'target:%s:%s\n' "$db" "$sql" >> "$grant_calls"
    cat "$2" >> "$grant_calls"
    return 0
  fi
  printf 'target:%s:%s\n' "$db" "$sql" >> "$grant_calls"
  cat >> "$grant_calls"
}
match_grants_db maestro_core_db >/tmp/match-grants.out 2>/tmp/match-grants.err
assert_contains "$(cat "$grant_calls")" 'GRANT USAGE ON SCHEMA public TO prod_app_role;' 'match-grants replays schema grants'
assert_contains "$(cat "$grant_calls")" 'GRANT SELECT,INSERT ON TABLE public.orders TO prod_app_role;' 'match-grants replays table grants'
assert_contains "$(cat "$grant_calls")" 'GRANT USAGE,SELECT ON SEQUENCE public.orders_id_seq TO prod_app_role;' 'match-grants replays sequence grants'
assert_contains "$(cat "$grant_calls")" 'GRANT prod_app_role TO prod_customer_app_user;' 'match-grants replays compatible role memberships'
assert_not_contains "$(cat "$grant_calls")" 'TO rds_superuser' 'match-grants skips protected RDS roles'
assert_not_contains "$(cat "$grant_calls")" 'TO missing_role' 'match-grants skips roles absent on target'
assert_not_contains "$(cat "$grant_calls")" 'excluded_source_only' 'match-grants skips source objects absent on target'
assert_contains "$(cat "$grant_calls")" "n.nspname !~ '^pg_temp_'" 'match-grants excludes transient PostgreSQL temp schemas'
assert_contains "$(cat "$grant_calls")" "n.nspname !~ '^pg_toast_temp_'" 'match-grants excludes transient PostgreSQL temp toast schemas'

: > "$grant_calls"
match_grants_dryrun_db maestro_core_db >/tmp/match-grants-dryrun.out 2>/tmp/match-grants-dryrun.err
assert_contains "$(cat /tmp/match-grants-dryrun.out)" 'GRANT USAGE ON SCHEMA public TO prod_app_role;' 'match-grants-dryrun prints source grants that would be applied'
assert_contains "$(cat /tmp/match-grants-dryrun.out)" 'grant_dryrun db=tgt_maestro statements=4' 'match-grants-dryrun reports statement count'
assert_not_contains "$(cat "$grant_calls")" 'target:tgt_maestro:-f' 'match-grants-dryrun must not apply target SQL files'

source_psql() {
  echo 'source grant query failed' >&2
  return 1
}
if match_grants_db maestro_core_db >/tmp/match-grants-fail.out 2>/tmp/match-grants-fail.err; then
  fail 'match-grants must fail when source grant discovery fails'
fi
assert_contains "$(cat /tmp/match-grants-fail.err)" 'source grant query failed' 'match-grants surfaces source query failure'

export DATABASES_JSON='[{"name":"citadel_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub"}]'

source_psql() {
  db="$1"
  shift
  sql="$*"
  case "$sql" in
    *-Atc\ * | *-tc\ * | *-c\ *) ;;
    *) sql="$sql $(cat)" ;;
  esac
  if printf '%s' "$sql" | grep -F "pg_class c" >/dev/null; then
    printf '%s\n' 'public.matching_table' 'public.audit_log'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "count(*) from public.matching_table" >/dev/null; then
    printf '%s' '3'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "count(*) from public.audit_log" >/dev/null; then
    printf '%s' '78'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "from pg_replication_slots" >/dev/null; then
    printf '%s' 'slot=sub,active=t,retained_wal_bytes=56'
    return 0
  fi
  fail "unexpected source_psql call for $db: $sql"
}

target_psql() {
  db="$1"
  shift
  sql="$*"
  if printf '%s' "$sql" | grep -F "count(*) from public.matching_table" >/dev/null; then
    printf '%s' '3'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "count(*) from public.audit_log" >/dev/null; then
    printf '%s' '71'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "from pg_subscription" >/dev/null; then
    printf '%s\n' 'subscription=sub,enabled=t' 'received_lsn=0/1,latest_end_lsn=0/1,lag_bytes=0'
    return 0
  fi
  fail "unexpected target_psql call for $db: $sql"
}

if verify_parity_db citadel_db >/tmp/verify-parity.out 2>/tmp/verify-parity.err; then
  fail 'parity mismatch must exit non-zero'
fi
assert_contains "$(cat /tmp/verify-parity.out)" 'public.audit_log source=78 target=71 delta=7' 'parity output names mismatch'
[ "$(cat "$STATE_DIR/last_parity")" = 'MISMATCH: public.audit_log source=78 target=71' ] || fail 'parity mismatch is stored'
[ "$(cat "$STATE_DIR/last_parity_at")" = '2026-08-13T10:00:00Z' ] || fail 'parity timestamp is stored'

rm -f "$STATE_DIR"/*
export DATABASES_JSON='[{"name":"maestro_core_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub","exclude_schemas":["partman"],"exclude_tables":["public.audit_log"]}]'
parity_filter_calls="$STATE_DIR/parity-filter-calls"
source_psql() {
  db="$1"
  shift
  sql="$*"
  case "$sql" in
    *-Atc\ * | *-tc\ * | *-c\ *) ;;
    *) sql="$sql $(cat)" ;;
  esac
  printf 'source:%s:%s\n' "$db" "$sql" >> "$parity_filter_calls"
  if printf '%s' "$sql" | grep -F "jsonb_array_elements_text" >/dev/null; then
    printf '%s\n' 'public.matching_table'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "count(*) from public.matching_table" >/dev/null; then
    printf '%s' '3'
    return 0
  fi
  fail "unexpected source_psql call for filtered parity: $db $sql"
}
target_psql() {
  db="$1"
  shift
  sql="$*"
  printf 'target:%s:%s\n' "$db" "$sql" >> "$parity_filter_calls"
  if printf '%s' "$sql" | grep -F "count(*) from public.matching_table" >/dev/null; then
    printf '%s' '3'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "public.audit_log" >/dev/null || printf '%s' "$sql" | grep -F "partman.part_config" >/dev/null; then
    fail "filtered parity must not count excluded table: $sql"
  fi
  fail "unexpected target_psql call for filtered parity: $db $sql"
}
verify_parity_db maestro_core_db >/tmp/verify-parity-filtered.out 2>/tmp/verify-parity-filtered.err
assert_contains "$(cat "$parity_filter_calls")" '-v exclude_schemas=["partman"]' 'parity reads schema excludes from database config'
assert_contains "$(cat "$parity_filter_calls")" '-v exclude_tables=["public.audit_log"]' 'parity reads table excludes from database config'
assert_contains "$(cat "$parity_filter_calls")" "n.nspname !~ '^pg_temp_'" 'parity excludes transient PostgreSQL temp schemas'
assert_contains "$(cat "$parity_filter_calls")" "n.nspname !~ '^pg_toast_temp_'" 'parity excludes transient PostgreSQL temp toast schemas'
assert_contains "$(cat /tmp/verify-parity-filtered.out)" 'public.matching_table source=3 target=3 delta=0' 'filtered parity still checks included tables'
assert_not_contains "$(cat /tmp/verify-parity-filtered.out)" 'public.audit_log' 'filtered parity omits excluded tables'
assert_not_contains "$(cat /tmp/verify-parity-filtered.out)" 'partman.part_config' 'filtered parity omits excluded schemas'

export DATABASES_JSON='[{"name":"citadel_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub"}]'

source_psql() {
  db="$1"
  shift
  sql="$*"
  if printf '%s' "$sql" | grep -F "from pg_replication_slots" >/dev/null; then
    printf '%s' 'slot=sub,active=t,restart_lsn=0/8,confirmed_flush_lsn=0/10,retained_wal_bytes=56,lag_bytes=42'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "confirmed_flush_lsn" >/dev/null; then
    printf '%s' '42'
    return 0
  fi
  fail "unexpected source_psql call for lag: $db $sql"
}

target_psql() {
  db="$1"
  shift
  sql="$*"
  if printf '%s' "$sql" | grep -F "from pg_subscription" >/dev/null; then
    printf '%s\n' 'subscription=sub,enabled=t' 'received_lsn=0/1,latest_end_lsn=0/1'
    return 0
  fi
  fail "unexpected target_psql call for lag: $db $sql"
}

verify_lag_db citadel_db >/tmp/verify-lag.out 2>/tmp/verify-lag.err
assert_contains "$(cat /tmp/verify-lag.out)" 'retained_wal_bytes=56' 'lag output includes retained WAL'
assert_contains "$(cat /tmp/verify-lag.out)" 'confirmed_flush_lsn=0/10' 'lag output includes source confirmed flush LSN'
assert_contains "$(cat /tmp/verify-lag.out)" 'lag_bytes=42' 'lag output includes source-side lag'
assert_not_contains "$(cat /tmp/verify-lag.out)" 'latest_end_lsn=0/1,lag_bytes=0' 'lag output must not compute lag from subscriber-local LSNs'
[ "$(cat "$STATE_DIR/last_lag")" = 'slot sub retained=56B lag=42B' ] || fail 'lag summary is stored'
[ "$(cat "$STATE_DIR/last_lag_at")" = '2026-08-13T10:00:00Z' ] || fail 'lag timestamp is stored'

if ! grep -n "slot_name = :'slot'" "$MODULE_DIR/scripts/replicate.sh" >/tmp/slot-name-guard-lines; then
  fail 'slot cleanup must constrain slot_name to the configured subscription'
fi
if ! grep -n "database = :'source_db'" "$MODULE_DIR/scripts/replicate.sh" >/tmp/slot-db-guard-lines; then
  fail 'slot cleanup must constrain database to the configured source_db'
fi
if ! grep -n "slot_type = 'logical'" "$MODULE_DIR/scripts/replicate.sh" >/tmp/slot-type-guard-lines; then
  fail 'slot cleanup must constrain slot_type to logical'
fi
if ! grep -n "plugin = 'pgoutput'" "$MODULE_DIR/scripts/replicate.sh" >/tmp/slot-plugin-guard-lines; then
  fail 'slot cleanup must constrain plugin to pgoutput'
fi
if grep -n "slot_name LIKE" "$MODULE_DIR/scripts/replicate.sh" >/tmp/slot-like-lines; then
  fail "slot cleanup must never use broad slot_name LIKE matching: $(cat /tmp/slot-like-lines)"
fi

if ! grep -n 'rebaseline-selected = {' "$MODULE_DIR/actions.tf" >/tmp/rebaseline-action-lines; then
  fail 'actions must expose rebaseline-selected'
fi
if ! grep -n 'stop-selected = {' "$MODULE_DIR/actions.tf" >/tmp/stop-action-lines; then
  fail 'actions must expose stop-selected'
fi
if ! grep -n 'stop-all = {' "$MODULE_DIR/actions.tf" >/tmp/stop-all-action-lines; then
  fail 'actions must expose stop-all'
fi
if ! grep -n 'stop-selected|stop-all)' "$MODULE_DIR/scripts/replicate.sh" >/tmp/stop-mode-lines; then
  fail 'main must expose stop-selected mode'
fi
if ! grep -n 'stop-selected|stop-all)' "$MODULE_DIR/scripts/replicate.sh" >/tmp/stop-all-mode-lines; then
  fail 'main must expose stop-all mode'
fi
if grep -A8 'stop-all = {' "$MODULE_DIR/actions.tf" | grep -F '$(params.dbs)' >/tmp/stop-all-param-lines; then
  fail "stop-all must not require a dbs parameter: $(cat /tmp/stop-all-param-lines)"
fi
if ! grep -n 'REBASELINE_ID' "$MODULE_DIR/actions.tf" >/tmp/rebaseline-env-lines; then
  fail 'actions must pass REBASELINE_ID into the spawned job'
fi
if grep -n 'kubectl set .*--local' "$MODULE_DIR/actions.tf" >/tmp/kubectl-local-lines; then
  fail "actions must not use kubectl set --local; the action image does not support it: $(cat /tmp/kubectl-local-lines)"
fi
if grep -n 'kubectl set args' "$MODULE_DIR/actions.tf" >/tmp/kubectl-set-args-lines; then
  fail "actions must not use kubectl set args; the action image does not support -f there: $(cat /tmp/kubectl-set-args-lines)"
fi
if grep -n 'kubectl set env' "$MODULE_DIR/actions.tf" >/tmp/kubectl-set-env-lines; then
  fail "actions must not use kubectl set env; the action image does not support -f there reliably: $(cat /tmp/kubectl-set-env-lines)"
fi
if ! grep -n 'kubectl patch --local -f - --type=json' "$MODULE_DIR/actions.tf" >/tmp/kubectl-patch-local-lines; then
  fail 'actions must JSON-patch the dry-run Job manifest locally before creating it'
fi
if grep -n 'containers":\[{"name":"driver","env"' "$MODULE_DIR/actions.tf" >/tmp/strategic-container-replace-lines; then
  fail "actions must not replace the container list because that drops image in local kubectl patch: $(cat /tmp/strategic-container-replace-lines)"
fi
if ! grep -n 'ACTION_MODE_OVERRIDE' "$MODULE_DIR/scripts/replicate.sh" >/tmp/action-mode-override-lines; then
  fail 'replicate.sh must honor ACTION_MODE_OVERRIDE from Facets actions'
fi
if ! grep -n 'login_roles:' "$MODULE_DIR/facets.yaml" >/tmp/login-roles-schema-lines; then
  fail 'facets schema must expose target.login_roles'
fi
if ! grep -n 'require_target_login_roles:' "$MODULE_DIR/facets.yaml" >/tmp/require-login-roles-schema-lines; then
  fail 'facets schema must expose options.require_target_login_roles'
fi
if ! grep -n 'target_login_role_mode:' "$MODULE_DIR/facets.yaml" >/tmp/target-login-role-mode-schema-lines; then
  fail 'facets schema must expose options.target_login_role_mode'
fi
if ! grep -n 'TARGET_LOGIN_ROLE_MODE=' "$MODULE_DIR/main.tf" >/tmp/target-login-role-mode-env-lines; then
  fail 'runner config must pass options.target_login_role_mode to replicate.sh'
fi
if ! grep -n 'resource "random_password" "target_login_roles"' "$MODULE_DIR/main.tf" >/tmp/target-role-password-lines; then
  fail 'terraform must generate one password per configured target login role'
fi
if ! grep -n 'resource "kubernetes_secret_v1" "target_login_role_passwords"' "$MODULE_DIR/main.tf" >/tmp/target-role-secret-lines; then
  fail 'terraform must write target login role passwords to a Kubernetes Secret'
fi
if ! grep -n 'TARGET_LOGIN_ROLE_PASSWORDS_JSON' "$MODULE_DIR/main.tf" >/tmp/target-role-secret-env-lines; then
  fail 'runner env must mount generated target login role passwords'
fi
if ! grep -n 'kubernetes_secret_v1.runner_credentials' "$MODULE_DIR/main.tf" >/tmp/runner-credential-secret-lines; then
  fail 'runner credentials must be stored in a Kubernetes Secret'
fi
if ! grep -n 'source_admin_password' "$MODULE_DIR/main.tf" >/tmp/source-admin-secret-key-lines; then
  fail 'source admin password must be mounted through a Kubernetes Secret env ref to preserve shell metacharacters'
fi
if ! grep -n 'require_target_login_roles_configured || return 1' "$MODULE_DIR/scripts/replicate.sh" >/tmp/target-role-preflight-guard-lines; then
  fail 'preflight must guard against missing target login roles before connecting'
fi
if ! grep -n 'target_login_role_passwords' "$MODULE_DIR/outputs.tf" >/tmp/target-role-output-lines; then
  fail 'module must output generated target login role passwords'
fi
if ! grep -A6 'output "target_login_role_passwords"' "$MODULE_DIR/outputs.tf" | grep -F 'sensitive = true' >/tmp/target-role-output-sensitive-lines; then
  fail 'target login role password output must be sensitive'
fi
if ! grep -nF 'verbs     = ["get", "create", "patch", "update"]' "$MODULE_DIR/main.tf" >/tmp/rbac-update-lines; then
  fail 'runner RBAC must allow configmap update for mutation-lock PUT'
fi
if ! grep -A4 'verify-lag = {' "$MODULE_DIR/main.tf" | grep -F 'schedule = "*/15 * * * *"' >/tmp/verify-lag-cron-lines; then
  fail 'verify-lag cron must run every 15 minutes'
fi
if ! grep -A4 'verify-lag = {' "$MODULE_DIR/main.tf" | grep -F 'suspend  = !local.allow_mutation' >/tmp/verify-lag-suspend-lines; then
  fail 'verify-lag cron must be suspended when mutation is disabled'
fi
if ! grep -A4 'poller = {' "$MODULE_DIR/main.tf" | grep -F 'suspend  = !local.allow_mutation' >/tmp/poller-suspend-lines; then
  fail 'poller cron must be suspended when mutation is disabled'
fi
if ! grep -A4 'verify-parity = {' "$MODULE_DIR/main.tf" | grep -F 'schedule = "0 0 31 2 *"' >/tmp/verify-parity-cron-lines; then
  fail 'verify-parity cron must be manual-only'
fi
if ! grep -A4 'verify-parity = {' "$MODULE_DIR/main.tf" | grep -F 'suspend  = true' >/tmp/verify-parity-suspend-lines; then
  fail 'verify-parity cron must be suspended by default'
fi

rm -f "$STATE_DIR"/*
export DATABASES_JSON='[{"name":"citadel_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub"}]'
export REBASELINE_ID=''
target_psql() {
  db="$1"
  shift
  sql="$*"
  if printf '%s' "$sql" | grep -F "select coalesce(subenabled::text" >/dev/null; then
    printf '%s' 'false'
    return 0
  fi
  fail "unexpected target_psql call while testing disabled subscription: $db $sql"
}
source_psql() {
  fail "load_db must not touch source when refusing disabled subscription"
}
if load_db citadel_db >/tmp/load-disabled.out 2>/tmp/load-disabled.err; then
  fail 'LOAD must refuse an existing disabled subscription outside rebaseline'
fi
assert_contains "$(cat /tmp/load-disabled.err)" 'REFUSED: subscription exists but is disabled' 'disabled subscription refusal is explicit'

rm -f "$STATE_DIR"/*
export DATABASES_JSON='[{"name":"citadel_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub"}]'
export REBASELINE_ID=''
load_ssl_calls="$WORK_DIR/load-ssl-calls.log"
target_psql() {
  db="$1"
  shift
  sql="$(cat)"
  printf '%s:%s:%s\n' "$db" "$*" "$sql" >> "$load_ssl_calls"
  if printf '%s' "$*" | grep -F "select coalesce(subenabled::text" >/dev/null; then
    return 0
  fi
}
source_psql() {
  fail "load_db must not connect to source directly when creating subscription"
}
wait_tables_copy_finished_with_incremental_primary() {
  return 0
}
load_db citadel_db >/tmp/load-ssl.out 2>/tmp/load-ssl.err
assert_contains "$(cat "$load_ssl_calls")" 'sslmode=require' 'LOAD subscription connection must require SSL to source'
assert_not_contains "$(cat /tmp/load-ssl.out)" 'source-repl-secret' 'LOAD subscription stdout does not expose replication password'
assert_not_contains "$(cat /tmp/load-ssl.err)" 'source-repl-secret' 'LOAD subscription stderr does not expose replication password'

rm -f "$STATE_DIR"/*
export REQUIRE_TARGET_LOGIN_ROLES=true
export TARGET_LOGIN_ROLES_JSON='[]'
source_psql() {
  fail "preflight must not connect to source when target login roles are required but empty"
}
target_psql() {
  fail "preflight must not connect to target when target login roles are required but empty"
}
if require_target_login_roles_configured >/tmp/preflight-roles-empty.out 2>/tmp/preflight-roles-empty.err; then
  fail 'preflight must refuse when target login roles are required but empty'
fi
assert_contains "$(cat /tmp/preflight-roles-empty.out)" 'REFUSED: target.login_roles is empty' 'empty target login roles refusal is explicit'
export REQUIRE_TARGET_LOGIN_ROLES=false
export TARGET_LOGIN_ROLES_JSON='[]'

rm -f "$STATE_DIR"/*
role_calls="$STATE_DIR/role-calls"
export TARGET_LOGIN_ROLES_JSON='["app_user","report_user"]'
export TARGET_LOGIN_ROLE_PASSWORDS_JSON='{"app_user":"pw-app","report_user":"pw-report"}'
target_psql() {
  db="$1"
  shift
  printf 'target:%s:%s\n' "$db" "$*" >> "$role_calls"
  cat >> "$role_calls"
}
ensure_target_login_roles citadel_db >/tmp/target-roles.out 2>/tmp/target-roles.err
assert_contains "$(cat "$role_calls")" 'CREATE ROLE %I WITH LOGIN PASSWORD %L' 'target login role setup creates missing login roles'
assert_contains "$(cat "$role_calls")" 'ALTER ROLE %I WITH LOGIN PASSWORD %L' 'target login role setup rotates existing login role passwords'
assert_contains "$(cat "$role_calls")" "rolname = :'role'" 'target login role setup checks exact role name'
assert_not_contains "$(cat /tmp/target-roles.out)" 'pw-app' 'target login role setup does not print passwords in logs'
export TARGET_LOGIN_ROLES_JSON='[]'
export TARGET_LOGIN_ROLE_PASSWORDS_JSON='{}'
export TARGET_LOGIN_ROLE_MODE='manage'

rm -f "$STATE_DIR"/*
skip_role_calls="$STATE_DIR/skip-role-calls"
export TARGET_LOGIN_ROLE_MODE='skip'
export TARGET_LOGIN_ROLES_JSON='["app_user"]'
export TARGET_LOGIN_ROLE_PASSWORDS_JSON='{"app_user":"pw-app"}'
target_psql() {
  printf 'unexpected target role write\n' >> "$skip_role_calls"
  return 1
}
ensure_target_login_roles citadel_db >/tmp/skip-target-roles.out 2>/tmp/skip-target-roles.err
[ ! -f "$skip_role_calls" ] || fail 'target login role mode skip must not query or write target roles'
assert_contains "$(cat /tmp/skip-target-roles.out)" 'target_login_role_mode_skip' 'skip mode logs that target role management is disabled'
assert_not_contains "$(cat /tmp/skip-target-roles.out)" 'pw-app' 'skip mode does not print passwords'
export TARGET_LOGIN_ROLE_MODE='manage'
export TARGET_LOGIN_ROLES_JSON='[]'
export TARGET_LOGIN_ROLE_PASSWORDS_JSON='{}'

rm -f "$STATE_DIR"/*
create_missing_role_calls="$STATE_DIR/create-missing-role-calls"
export TARGET_LOGIN_ROLE_MODE='create_missing'
export TARGET_LOGIN_ROLES_JSON='["existing_user","new_user"]'
export TARGET_LOGIN_ROLE_PASSWORDS_JSON='{"existing_user":"pw-existing","new_user":"pw-new"}'
target_psql() {
  db="$1"
  shift
  printf 'target:%s:%s\n' "$db" "$*" >> "$create_missing_role_calls"
  cat >> "$create_missing_role_calls"
  if printf '%s' "$*" | grep -F "rolname = :'role'" >/dev/null; then
    case "$*" in
      *existing_user*) printf 'true' ;;
      *) printf 'false' ;;
    esac
  fi
}
ensure_target_login_roles citadel_db >/tmp/create-missing-target-roles.out 2>/tmp/create-missing-target-roles.err
create_missing_role_log="$(cat "$create_missing_role_calls")"
assert_contains "$create_missing_role_log" 'CREATE ROLE %I WITH LOGIN PASSWORD %L' 'create_missing mode creates absent login roles'
assert_not_contains "$create_missing_role_log" 'ALTER ROLE %I WITH LOGIN PASSWORD %L' 'create_missing mode must not alter existing role passwords'
assert_contains "$(cat /tmp/create-missing-target-roles.out)" 'target_login_role_exists role=existing_user' 'create_missing mode logs existing role skip'
assert_contains "$(cat /tmp/create-missing-target-roles.out)" 'target_login_role_create role=new_user' 'create_missing mode logs missing role create'
assert_not_contains "$(cat /tmp/create-missing-target-roles.out)" 'pw-existing' 'create_missing mode does not print existing password'
assert_not_contains "$(cat /tmp/create-missing-target-roles.out)" 'pw-new' 'create_missing mode does not print new password'
export TARGET_LOGIN_ROLE_MODE='manage'
export TARGET_LOGIN_ROLES_JSON='[]'
export TARGET_LOGIN_ROLE_PASSWORDS_JSON='{}'

rm -f "$STATE_DIR"/*
protected_role_calls="$STATE_DIR/protected-role-calls"
export TARGET_ADMIN_USER='postgres'
export TARGET_REPL_USER='migration_repl'
export TARGET_LOGIN_ROLES_JSON='["postgres","migration_repl","pg_monitor","app_user"]'
export TARGET_LOGIN_ROLE_PASSWORDS_JSON='{"postgres":"pw-postgres","migration_repl":"pw-repl","pg_monitor":"pw-pg","app_user":"pw-app"}'
target_psql() {
  db="$1"
  shift
  printf 'target:%s:%s\n' "$db" "$*" >> "$protected_role_calls"
  cat >> "$protected_role_calls"
}
ensure_target_login_roles citadel_db >/tmp/protected-target-roles.out 2>/tmp/protected-target-roles.err
protected_role_log="$(cat "$protected_role_calls")"
assert_contains "$protected_role_log" 'app_user' 'target login role setup still creates normal roles'
assert_not_contains "$protected_role_log" 'pw-postgres' 'target login role setup must not rotate target admin password'
assert_not_contains "$protected_role_log" 'pw-repl' 'target login role setup must not rotate target replication password'
assert_not_contains "$protected_role_log" 'pw-pg' 'target login role setup must not rotate pg system roles'
assert_contains "$(cat /tmp/protected-target-roles.out)" 'target_login_role_skip_protected role=postgres' 'protected target admin role skip is logged'
assert_contains "$(cat /tmp/protected-target-roles.out)" 'target_login_role_skip_protected role=migration_repl' 'protected target replication role skip is logged'
assert_contains "$(cat /tmp/protected-target-roles.out)" 'target_login_role_skip_protected role=pg_monitor' 'protected pg role skip is logged'
export TARGET_ADMIN_USER='target_admin'
export TARGET_REPL_USER='target_repl'
export TARGET_LOGIN_ROLES_JSON='[]'
export TARGET_LOGIN_ROLE_PASSWORDS_JSON='{}'

rm -f "$STATE_DIR"/*
schema_calls="$STATE_DIR/schema-calls"
export TARGET_LOGIN_ROLES_JSON='["app_user"]'
export TARGET_LOGIN_ROLE_PASSWORDS_JSON='{"app_user":"pw-app"}'
target_public_objects() {
  printf ''
}
target_psql() {
  db="$1"
  shift
  printf 'target:%s:%s\n' "$db" "$*" >> "$schema_calls"
  if [ "${1:-}" = "-f" ] && [ -n "${2:-}" ]; then
    cat "$2" >> "$schema_calls"
    return 0
  fi
  cat >> "$schema_calls"
}
PGPASSWORD() { :; }
pg_dump() {
  printf '%s\n' 'CREATE TABLE public.t(id integer);'
}
schema_db citadel_db >/tmp/schema-role.out 2>/tmp/schema-role.err
schema_log="$(cat "$schema_calls")"
role_line="$(printf '%s\n' "$schema_log" | grep -n 'CREATE ROLE %I WITH LOGIN PASSWORD %L' | sed -n '1s/:.*//p')"
schema_line="$(printf '%s\n' "$schema_log" | grep -n 'CREATE TABLE public.t' | sed -n '1s/:.*//p')"
[ -n "$role_line" ] || fail 'SCHEMA must create target login roles'
[ -n "$schema_line" ] || fail 'SCHEMA must restore schema'
[ "$role_line" -lt "$schema_line" ] || fail 'SCHEMA must create target login roles before restoring schema'
export TARGET_LOGIN_ROLES_JSON='[]'
export TARGET_LOGIN_ROLE_PASSWORDS_JSON='{}'

rm -f "$STATE_DIR"/*
rebaseline_calls="$STATE_DIR/rebaseline-calls"
export REBASELINE_ID='pitr-001'
export ALLOW_SCHEMA_RESET=true
export ALLOW_MUTATION=true
target_psql() {
  db="$1"
  shift
  printf 'target:%s:%s\n' "$db" "$*" >> "$rebaseline_calls"
  cat >> "$rebaseline_calls"
}
source_psql() {
  db="$1"
  shift
  printf 'source:%s:%s\n' "$db" "$*" >> "$rebaseline_calls"
  cat >> "$rebaseline_calls"
}
rebaseline_db citadel_db >/tmp/rebaseline.out 2>/tmp/rebaseline.err
assert_contains "$(cat "$rebaseline_calls")" 'DROP SUBSCRIPTION %I' 'rebaseline drops configured target subscription'
assert_contains "$(cat "$rebaseline_calls")" 'ALTER SUBSCRIPTION %I DISABLE' 'rebaseline disables target subscription before dropping'
assert_contains "$(cat "$rebaseline_calls")" 'ALTER SUBSCRIPTION %I SET (slot_name = NONE)' 'rebaseline detaches publisher slot before dropping target subscription'
assert_contains "$(cat "$rebaseline_calls")" "slot_name = :'slot'" 'rebaseline source slot cleanup is exact-name guarded'
assert_contains "$(cat "$rebaseline_calls")" "database = :'source_db'" 'rebaseline source slot cleanup is source-db guarded'
assert_contains "$(cat "$rebaseline_calls")" "slot_type = 'logical'" 'rebaseline source slot cleanup is slot-type guarded'
assert_contains "$(cat "$rebaseline_calls")" "plugin = 'pgoutput'" 'rebaseline source slot cleanup is plugin guarded'
rebaseline_state="$(cat "$STATE_DIR/db-citadel_db")"
[ "$(printf '%s' "$rebaseline_state" | jq -r '.rebaseline_id')" = 'pitr-001' ] || fail 'rebaseline stores rebaseline_id in db state'
[ "$(printf '%s' "$rebaseline_state" | jq -r '.last_completed_phase')" = 'NONE' ] || fail 'rebaseline resets last_completed_phase to NONE'

rm -f "$STATE_DIR"/*
export REBASELINE_ID=''
export ALLOW_SCHEMA_RESET=false
export ALLOW_MUTATION=true
write_db_state citadel_db STEADY STEADY "" 0 0
export REBASELINE_ID='pitr-refused'
run_phase() {
  fail 'run_driver_db must not continue into normal phases after rebaseline refusal'
}
if run_driver_db citadel_db >/tmp/run-rebaseline-refused.out 2>/tmp/run-rebaseline-refused.err; then
  fail 'run_driver_db must fail when requested rebaseline is refused'
fi
assert_contains "$(cat /tmp/run-rebaseline-refused.err)" 'REFUSED: rebaseline requires ALLOW_SCHEMA_RESET=true' 'rebaseline refusal is surfaced'
refused_state="$(cat "$STATE_DIR/db-citadel_db")"
[ "$(printf '%s' "$refused_state" | jq -r '.phase')" = 'BLOCKED' ] || fail 'refused rebaseline marks db blocked'
[ "$(printf '%s' "$refused_state" | jq -r '.last_completed_phase')" = 'STEADY' ] || fail 'refused rebaseline preserves last completed phase'

rm -f "$STATE_DIR"/*
stop_calls="$STATE_DIR/stop-calls"
export REBASELINE_ID=''
export ALLOW_SCHEMA_RESET=false
export ALLOW_MUTATION=true
export DATABASES_JSON='[{"name":"citadel_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub"}]'
write_db_state citadel_db INDEX LOAD "phase failed" 0 0
target_psql() {
  db="$1"
  shift
  printf 'target:%s:%s\n' "$db" "$*" >> "$stop_calls"
  cat >> "$stop_calls"
}
source_psql() {
  db="$1"
  shift
  printf 'source:%s:%s\n' "$db" "$*" >> "$stop_calls"
  cat >> "$stop_calls"
}
stop_db citadel_db >/tmp/stop.out 2>/tmp/stop.err
assert_contains "$(cat "$stop_calls")" 'DROP SUBSCRIPTION %I' 'stop drops configured target subscription'
assert_contains "$(cat "$stop_calls")" 'ALTER SUBSCRIPTION %I DISABLE' 'stop disables target subscription before dropping'
assert_contains "$(cat "$stop_calls")" 'ALTER SUBSCRIPTION %I SET (slot_name = NONE)' 'stop detaches publisher slot before dropping target subscription'
assert_contains "$(cat "$stop_calls")" "slot_name = :'slot'" 'stop source slot cleanup is exact-name guarded'
assert_contains "$(cat "$stop_calls")" "database = :'source_db'" 'stop source slot cleanup is source-db guarded'
stopped_state="$(cat "$STATE_DIR/db-citadel_db")"
[ "$(printf '%s' "$stopped_state" | jq -r '.phase')" = 'STOPPED' ] || fail 'stop records STOPPED phase'
[ "$(printf '%s' "$stopped_state" | jq -r '.last_completed_phase')" = 'LOAD' ] || fail 'stop preserves previous completed phase'

rm -f "$STATE_DIR"/*
blocked_mutation_calls="$STATE_DIR/blocked-mutation-calls"
export ALLOW_MUTATION=false
export REBASELINE_ID=''
export ALLOW_SCHEMA_RESET=false
export DATABASES_JSON='[{"name":"citadel_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub"}]'
write_db_state citadel_db STEADY STEADY "" 0 0
target_psql() {
  printf 'target:%s:%s\n' "$1" "$*" >> "$blocked_mutation_calls"
}
source_psql() {
  printf 'source:%s:%s\n' "$1" "$*" >> "$blocked_mutation_calls"
}
if stop_db citadel_db >/tmp/stop-mutation-blocked.out 2>/tmp/stop-mutation-blocked.err; then
  fail 'stop must be refused when options.allow_mutation=false'
fi
assert_contains "$(cat /tmp/stop-mutation-blocked.err)" 'REFUSED: mutating replication actions are disabled by options.allow_mutation=false' 'mutation block refusal is explicit'
if [ -f "$blocked_mutation_calls" ]; then
  fail "mutation-blocked stop must not touch source or target: $(cat "$blocked_mutation_calls")"
fi
export ALLOW_MUTATION=true

rm -f "$STATE_DIR"/*
export REBASELINE_ID=''
export ALLOW_SCHEMA_RESET=false
export ALLOW_MUTATION=true
export DEFER_SECONDARY_INDEXES=false
export DATABASES_JSON='[{"name":"citadel_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub"}]'
write_db_state citadel_db LOAD LOAD "" 0 0
source_psql() {
  db="$1"
  shift
  sql="$*"
  if printf '%s' "$sql" | grep -F "relkind in ('r','p')" >/dev/null; then
    printf '%s\n' '1'
    return 0
  fi
  fail "unexpected source_psql call while testing INDEX transition guard: $db $sql"
}
target_psql() {
  db="$1"
  shift
  sql="$*"
  if printf '%s' "$sql" | grep -F "pg_subscription_rel" >/dev/null; then
    printf '%s\n%s\n' '0' '0'
    return 0
  fi
  fail "unexpected target_psql call while testing INDEX transition guard: $db $sql"
}
run_phase() {
  fail 'run_driver_db must not enter INDEX when transition guard refuses'
}
if run_driver_db citadel_db >/tmp/run-index-guard.out 2>/tmp/run-index-guard.err; then
  fail 'run_driver_db must fail when INDEX transition guard refuses'
fi
assert_contains "$(cat /tmp/run-index-guard.err)" 'REFUSED: subscription tables are not all ready' 'INDEX transition guard refusal is surfaced'
index_guard_state="$(cat "$STATE_DIR/db-citadel_db")"
[ "$(printf '%s' "$index_guard_state" | jq -r '.phase')" = 'BLOCKED' ] || fail 'INDEX transition guard marks db blocked'
[ "$(printf '%s' "$index_guard_state" | jq -r '.last_completed_phase')" = 'LOAD' ] || fail 'INDEX transition guard preserves last completed phase'
export DEFER_SECONDARY_INDEXES=true

rm -f "$STATE_DIR"/*
cutover_calls="$STATE_DIR/cutover-calls"
export REBASELINE_ID=''
export ALLOW_SCHEMA_RESET=false
export ALLOW_MUTATION=true
export DATABASES_JSON='[{"name":"citadel_db","source_db":"src","target_db":"tgt","publication":"pub","subscription":"sub"}]'
source_psql() {
  db="$1"
  shift
  sql="$*"
  if printf '%s' "$sql" | grep -F "relkind in ('r','p')" >/dev/null; then
    printf '%s\n' '1'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "confirmed_flush_lsn" >/dev/null; then
    printf '%s\n' '42'
    return 0
  fi
  fail "unexpected source_psql call while testing cutover lag guard: $db $sql"
}
target_psql() {
  db="$1"
  shift
  sql="$*"
  if printf '%s' "$sql" | grep -F "select coalesce(subenabled::text" >/dev/null; then
    printf '%s\n' 'true'
    return 0
  fi
  if printf '%s' "$sql" | grep -F "pg_subscription_rel" >/dev/null; then
    printf '%s\n%s\n' '1' '1'
    return 0
  fi
  printf 'target:%s:%s\n' "$db" "$sql" >> "$cutover_calls"
  cat >> "$cutover_calls"
}
if sync_sequences_db citadel_db >/tmp/cutover-lag.out 2>/tmp/cutover-lag.err; then
  fail 'cutover sequence sync must fail when replication lag is non-zero'
fi
assert_contains "$(cat /tmp/cutover-lag.err)" 'REFUSED: replication lag is non-zero or unknown; lag_bytes=42' 'cutover lag guard refusal is explicit'
if [ -f "$cutover_calls" ]; then
  fail "cutover sequence sync must not write setval when lag guard refuses: $(cat "$cutover_calls")"
fi

rm -f "$STATE_DIR"/*
attach_calls="$STATE_DIR/attach-existing-calls"
attach_subscription_created="$STATE_DIR/attach-subscription-created"
export ALLOW_MUTATION=true
export ATTACH_CONFIRM_EXISTING_BASELINE=false
export ATTACH_CONFIRM_SOURCE_WRITES_FROZEN=false
source_psql() {
  printf 'source:%s:%s\n' "$1" "$*" >> "$attach_calls"
}
target_psql() {
  printf 'target:%s:%s\n' "$1" "$*" >> "$attach_calls"
}
if attach_existing_db citadel_db >/tmp/attach-confirm.out 2>/tmp/attach-confirm.err; then
  fail 'attach-existing must require explicit baseline and source-write confirmations'
fi
assert_contains "$(cat /tmp/attach-confirm.err)" 'confirm_existing_baseline=true' 'attach-existing names the baseline confirmation requirement'
assert_contains "$(cat /tmp/attach-confirm.err)" 'confirm_source_writes_frozen=true' 'attach-existing names the source-write confirmation requirement'
if [ -f "$attach_calls" ]; then
  fail "attach-existing must not query or mutate databases before confirmations: $(cat "$attach_calls")"
fi

rm -f "$STATE_DIR"/*
attach_calls="$STATE_DIR/attach-existing-calls"
export ATTACH_CONFIRM_EXISTING_BASELINE=true
export ATTACH_CONFIRM_SOURCE_WRITES_FROZEN=true
export ALLOW_MUTATION=false
if attach_existing_db citadel_db >/tmp/attach-mutation-blocked.out 2>/tmp/attach-mutation-blocked.err; then
  fail 'attach-existing must be refused when options.allow_mutation=false'
fi
assert_contains "$(cat /tmp/attach-mutation-blocked.err)" 'mutating replication actions are disabled' 'attach-existing honors the mutation guard'
if [ -f "$attach_calls" ]; then
  fail "mutation-blocked attach-existing must not touch source or target: $(cat "$attach_calls")"
fi

rm -f "$STATE_DIR"/*
attach_calls="$STATE_DIR/attach-existing-calls"
export ALLOW_MUTATION=true
source_psql() {
  db="$1"
  shift
  sql="$*"
  printf 'source:%s:%s\n' "$db" "$sql" >> "$attach_calls"
  if printf '%s' "$sql" | grep -F 'pg_subscription' >/dev/null; then
    printf '%s\n' 'forward_sub'
  fi
}
target_psql() {
  printf 'target:%s:%s\n' "$1" "$*" >> "$attach_calls"
}
if attach_existing_db citadel_db >/tmp/attach-forward-enabled.out 2>/tmp/attach-forward-enabled.err; then
  fail 'attach-existing must refuse while a forward subscription is enabled on the reverse source'
fi
assert_contains "$(cat /tmp/attach-forward-enabled.err)" 'enabled subscription' 'attach-existing reports enabled forward subscriptions'
assert_not_contains "$(cat "$attach_calls")" 'CREATE SUBSCRIPTION' 'forward-enabled refusal creates no reverse subscription'

rm -f "$STATE_DIR"/*
attach_calls="$STATE_DIR/attach-existing-calls"
source_psql() {
  db="$1"
  shift
  sql="$*"
  printf 'source:%s:%s\n' "$db" "$sql" >> "$attach_calls"
  if printf '%s' "$sql" | grep -F 'pg_subscription' >/dev/null; then
    printf ''
  fi
}
target_psql() {
  printf 'target:%s:%s\n' "$1" "$*" >> "$attach_calls"
}
verify_parity_db() {
  return 1
}
publish_db() {
  fail 'attach-existing must not publish when parity fails'
}
if attach_existing_db citadel_db >/tmp/attach-parity.out 2>/tmp/attach-parity.err; then
  fail 'attach-existing must refuse a baseline parity mismatch'
fi
assert_contains "$(cat /tmp/attach-parity.err)" 'baseline parity verification failed' 'attach-existing reports parity failure'
assert_not_contains "$(cat "$attach_calls")" 'CREATE SUBSCRIPTION' 'parity refusal creates no reverse subscription'

rm -f "$STATE_DIR"/*
attach_calls="$STATE_DIR/attach-existing-calls"
source_psql() {
  db="$1"
  shift
  sql="$*"
  printf 'source:%s:%s\n' "$db" "$sql" >> "$attach_calls"
  if printf '%s' "$sql" | grep -F 'pg_subscription' >/dev/null; then
    printf ''
  fi
}
target_psql() {
  db="$1"
  shift
  sql="$*"
  printf 'target:%s:%s\n' "$db" "$sql" >> "$attach_calls"
  cat >> "$attach_calls"
  if printf '%s' "$sql" | grep -F 'select coalesce(subenabled::text' >/dev/null; then
    if [ -f "$attach_subscription_created" ]; then
      printf '%s\n' 'true'
    else
      : > "$attach_subscription_created"
      printf '%s\n' 'MISSING'
    fi
  elif printf '%s' "$sql" | grep -F 'server_version_num' >/dev/null; then
    printf '%s\n' '150000'
  fi
}
verify_parity_db() {
  printf '%s\n' '1/1 tables match'
}
publish_db() {
  printf '%s\n' 'publication-ready' >> "$attach_calls"
}
write_db_state() {
  printf 'state:%s:%s:%s\n' "$1" "$2" "$3" >> "$attach_calls"
}
attach_existing_db citadel_db >/tmp/attach-success.out 2>/tmp/attach-success.err || fail 'attach-existing safe path should succeed'
attach_log="$(cat "$attach_calls")"
assert_contains "$attach_log" 'publication-ready' 'attach-existing prepares the publication'
assert_contains "$attach_log" 'CREATE SUBSCRIPTION' 'attach-existing creates the reverse subscription'
assert_contains "$attach_log" 'copy_data = false' 'attach-existing never performs an initial table copy'
assert_contains "$attach_log" 'origin = none' 'attach-existing prevents replay-origin loops on supported PostgreSQL'
assert_not_contains "$attach_log" 'copy_data = true' 'attach-existing never enables initial copy'
assert_not_contains "$attach_log" 'DROP SCHEMA' 'attach-existing never drops schemas'
assert_not_contains "$attach_log" 'schema_reset_sql' 'attach-existing never invokes schema reset'
assert_contains "$attach_log" 'state:citadel_db:STEADY:STEADY' 'attach-existing records a steady checkpoint'

rm -f "$STATE_DIR"/*
state_object="$STATE_DIR/state-object.json"
state_put_calls="$STATE_DIR/state-put-calls"
printf '%s' '{"apiVersion":"v1","kind":"ConfigMap","metadata":{"name":"state","resourceVersion":"1"},"data":{}}' > "$state_object"
kube_curl() {
  method="$1"
  path="$2"
  if [ "$method" = "GET" ] && printf '%s' "$path" | grep -F '/configmaps/' >/dev/null; then
    cat "$state_object"
    return 0
  fi
  fail "unexpected kube_curl call while testing locks: $method $path"
}
state_put() {
  body="$1"
  echo put >> "$state_put_calls"
  printf '%s' "$body" > "$state_object"
}
export RUN_LOCK_ID='owner-a'
export RUN_LOCK_TTL_SECONDS=60
acquire_mutation_lock driver >/tmp/lock-acquire.out 2>/tmp/lock-acquire.err || fail 'first mutating action should acquire lock'
lock_after_acquire="$(jq -r '.data.active_mutation_lock' "$state_object")"
assert_contains "$lock_after_acquire" '"owner":"owner-a"' 'mutation lock records owner'
assert_contains "$lock_after_acquire" '"mode":"driver"' 'mutation lock records mode'

export RUN_LOCK_ID='owner-b'
if acquire_mutation_lock driver >/tmp/lock-duplicate.out 2>/tmp/lock-duplicate.err; then
  fail 'duplicate mutating action must be refused while lock is active'
fi
assert_contains "$(cat /tmp/lock-duplicate.err)" 'REFUSED: another mutating replication action is active' 'duplicate mutation refusal is explicit'

state_patch active_mutation_lock "$lock_after_acquire"
if require_no_mutation_lock >/tmp/read-lock.out 2>/tmp/read-lock.err; then
  fail 'guarded read actions must refuse while mutating lock is active'
fi
assert_contains "$(cat /tmp/read-lock.err)" 'REFUSED: mutating replication action is active' 'read action lock refusal is explicit'

export RUN_LOCK_ID='owner-a'
release_mutation_lock
[ "$(jq -r '.data.active_mutation_lock // ""' "$state_object")" = "" ] || fail 'owner release removes its mutation lock'

expired_lock="$(jq -cn '{owner:"old-owner",mode:"driver",selected_dbs:"*",started_at_epoch:1,expires_at_epoch:2}')"
jq --arg lock "$expired_lock" '.data.active_mutation_lock = $lock' "$state_object" > "$state_object.tmp"
mv "$state_object.tmp" "$state_object"
export RUN_LOCK_ID='owner-c'
acquire_mutation_lock cutover >/tmp/lock-steal.out 2>/tmp/lock-steal.err || fail 'expired lock should be replaceable'
lock_after_steal="$(jq -r '.data.active_mutation_lock' "$state_object")"
assert_contains "$lock_after_steal" '"owner":"owner-c"' 'expired mutation lock can be replaced'
assert_contains "$lock_after_steal" '"mode":"cutover"' 'replacement lock records new mode'

echo "ok"

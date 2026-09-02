#!/usr/bin/env sh
set -eu

MODULE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MAIN_TF="$MODULE_DIR/main.tf"
LOCALS_TF="$MODULE_DIR/locals.tf"
OUTPUTS_TF="$MODULE_DIR/outputs.tf"
FACETS="$MODULE_DIR/facets.yaml"

# ── cluster mode must be selectable ───────────────────────────────────────────
# google_memorystore_instance supports mode = CLUSTER_ENABLED (gcloud --mode=cluster)
# and main.tf already passed spec.version_config.mode through, but the facets.yaml
# enum listed only CLUSTER_DISABLED so no blueprint could ask for it. payout-service
# needs it: its Spring prod profile sets spring.data.redis.cluster.nodes, and a
# cluster-disabled server answers "ERR This instance has cluster support disabled".
if ! grep -q 'CLUSTER_ENABLED' "$FACETS"; then
  echo "spec.version_config.mode must offer CLUSTER_ENABLED, not just CLUSTER_DISABLED"
  exit 1
fi

# ── databases is CLUSTER_DISABLED-only ────────────────────────────────────────
# Valkey in cluster mode has exactly one logical database (db 0); sending
# engine_configs.databases on such an instance is rejected by the API, so the key
# must be omitted entirely rather than pinned to "1".
if ! grep -q 'is_cluster_enabled' "$LOCALS_TF"; then
  echo "locals must expose is_cluster_enabled so mode-specific config can be gated"
  exit 1
fi
if grep -Eq '^\s*engine_configs\s*=\s*\{' "$MAIN_TF"; then
  echo "engine_configs must be built conditionally (merge), not a fixed map that always sets databases"
  exit 1
fi
if ! grep -q 'local.is_cluster_enabled ? {} :' "$MAIN_TF"; then
  echo "engine_configs must DROP the databases key when cluster mode is enabled"
  exit 1
fi
if ! grep -Eq '^\s*mode\s*=\s*local\.mode' "$MAIN_TF"; then
  echo "the resource must use local.mode so the value resolves in one place"
  exit 1
fi
if ! grep -q 'local.is_cluster_enabled ? 1 :' "$OUTPUTS_TF"; then
  echo "output_attributes.database_count must report 1 in cluster mode, not the unused spec value"
  exit 1
fi

# ── variables.tf must not re-block what facets.yaml now allows ────────────────
# The enum is only half the gate: variables.tf carried its own validation
# `mode == "CLUSTER_DISABLED"` with "This flavor is intentionally limited to
# CLUSTER_DISABLED mode." Relaxing facets.yaml alone left the plan failing at
# terraform validate — after the blueprint had already been changed.
VARS_TF="$MODULE_DIR/variables.tf"
if grep -Eq 'condition\s*=\s*var\.instance\.spec\.version_config\.mode\s*==\s*"CLUSTER_DISABLED"' "$VARS_TF"; then
  echo "variables.tf still hard-blocks CLUSTER_ENABLED; the mode validation must accept both modes"
  exit 1
fi
if ! grep -q 'contains(\["CLUSTER_DISABLED", "CLUSTER", "CLUSTER_ENABLED"\]' "$VARS_TF"; then
  echo "the mode validation must accept CLUSTER_DISABLED, CLUSTER and the CLUSTER_ENABLED alias"
  exit 1
fi
# shard_count == 1 is a CLUSTER_DISABLED rule; cluster mode may shard.
if grep -Eq 'condition\s*=\s*var\.instance\.spec\.sizing\.shard_count\s*==\s*1\s*$' "$VARS_TF"; then
  echo "shard_count validation must be mode-aware, not an unconditional == 1"
  exit 1
fi
# database_count range only means anything for CLUSTER_DISABLED (cluster has db 0 only).
if ! grep -q 'var.instance.spec.version_config.mode != "CLUSTER_DISABLED" ||' "$VARS_TF"; then
  echo "the database_count range must only be enforced in CLUSTER_DISABLED mode"
  exit 1
fi

# ── the provider enum is CLUSTER, not CLUSTER_ENABLED ─────────────────────────
# google_memorystore_instance accepts exactly ["CLUSTER" "CLUSTER_DISABLED" ""].
# The GCP REST API and gcloud spell cluster mode differently from each other, so
# the module accepts the API-style CLUSTER_ENABLED too and normalises it down to
# the provider's CLUSTER before the value reaches the resource. Sending
# CLUSTER_ENABLED straight through fails the plan with
#   expected mode to be one of ["CLUSTER" "CLUSTER_DISABLED" ""]
if ! grep -q 'mode_normalized' "$LOCALS_TF"; then
  echo "locals must normalise the mode to the provider vocabulary (mode_normalized)"
  exit 1
fi
if ! grep -Eq '"CLUSTER_ENABLED"\s*\?\s*"CLUSTER"' "$LOCALS_TF"; then
  echo "CLUSTER_ENABLED must be normalised to the provider value CLUSTER"
  exit 1
fi
if ! grep -Eq '^\s*mode\s*=\s*local\.mode_normalized' "$MAIN_TF"; then
  echo "the resource must receive the NORMALISED mode, never the raw spec value"
  exit 1
fi
if ! grep -q 'CLUSTER_ENABLED' "$FACETS" || ! grep -Eq '^\s*-\s*CLUSTER$' "$FACETS"; then
  echo "facets.yaml must offer both CLUSTER (provider value) and CLUSTER_ENABLED (API alias)"
  exit 1
fi

echo "ok"

# ── automated backups must be configurable ────────────────────────────────────
# AWS ElastiCache retains snapshots on 8 of the 11 prod instances (1-7 days);
# this module configured none, so every GCP instance reported
# automatedBackupMode: DISABLED. That is a silent durability regression for any
# instance holding state rather than pure cache.
if ! grep -q 'backup' "$FACETS"; then
  echo "facets.yaml must expose spec.backup so retention can be set per instance"
  exit 1
fi
if ! grep -q 'automated_backup_config' "$MAIN_TF"; then
  echo "main.tf must configure automated_backup_config"
  exit 1
fi
# The block is optional (max_items 1). It must be emitted via dynamic so that a
# disabled backup means the block is ABSENT, not present-and-empty - the API
# rejects an automated_backup_config without retention.
if ! grep -q 'dynamic "automated_backup_config"' "$MAIN_TF"; then
  echo "automated_backup_config must be a dynamic block so it disappears when disabled"
  exit 1
fi
# retention is a duration STRING in seconds per the provider schema, not a day count.
if ! grep -Eq 'retention\s*=\s*"\$\{.*86400\}s"' "$MAIN_TF"; then
  echo "retention must be rendered as a seconds duration string (days * 86400 + 's')"
  exit 1
fi
# start_time supports HOURS ONLY - the provider has no minutes attribute there.
if grep -A 6 'fixed_frequency_schedule' "$MAIN_TF" | grep -q 'minutes'; then
  echo "automated_backup_config start_time takes hours only; minutes is not a valid attribute"
  exit 1
fi
# Default OFF: this module version is already backing 11 live instances. Turning
# backups on by default would change every one of them on their next release.
if ! grep -q 'backup_enabled' "$LOCALS_TF"; then
  echo "locals must expose backup_enabled"
  exit 1
fi
if ! grep -Eq 'optional\(bool, false\)' "$MODULE_DIR/variables.tf"; then
  echo "spec.backup.enabled must default to FALSE so existing instances are unchanged"
  exit 1
fi
# A Facets optional() spec field materialises as null, and lookup() returns that
# null rather than the default - so the locals must null-guard explicitly.
if ! grep -q 'coalesce(try(var.instance.spec.backup' "$LOCALS_TF"; then
  echo "locals must null-guard spec.backup with coalesce(try(...)) before reading its keys"
  exit 1
fi
# An empty object and a typed object are different types, so `backup == null ? {} : backup`
# fails the plan with "Inconsistent conditional result types". terraform validate does NOT
# catch it - it only appeared at plan time against real resources.
if grep -v '^[[:space:]]*#' "$LOCALS_TF" | grep -Eq 'null \?\s*\{\}\s*:'; then
  echo "do not branch a typed object against {} - use coalesce(try(...)) instead"
  exit 1
fi

# ── maintenance start time is whole hours only ────────────────────────────────
# The schema advertised minute 0-59, but the API rejects any non-zero value with
# "Error 400: Invalid start time, only hours are supported" - which only appeared
# mid-apply, after four instances had already been updated.
if ! grep -q 'var.instance.spec.maintenance.minute == 0' "$MODULE_DIR/variables.tf"; then
  echo "maintenance.minute must be validated to 0; the API supports whole hours only"
  exit 1
fi
if grep -A 4 'title: Minute' "$FACETS" | grep -q 'maximum: 59'; then
  echo "facets.yaml still advertises minute up to 59; the API accepts 0 only"
  exit 1
fi

echo "all unit assertions passed"

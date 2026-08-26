locals {
  spec = var.instance.spec

  # RULE-015: every optional field is read through lookup()/try() rather than by
  # bare attribute access, because the control plane passes var.instance under its
  # own looser type and the optional() defaults declared above are not guaranteed
  # to have been materialised (see backlog IAM-2).
  user_spec   = lookup(local.spec, "user", {})
  username    = lookup(local.user_spec, "name", "")
  auth_plugin = coalesce(lookup(local.user_spec, "auth_plugin", null), "mysql_native_password")
  user_host   = coalesce(lookup(local.user_spec, "host", null), "%")

  databases = coalesce(lookup(local.spec, "databases", null), [])
  grants    = coalesce(lookup(local.spec, "grants", null), [])

  job_spec  = coalesce(lookup(local.spec, "job", null), {})
  namespace = coalesce(lookup(local.job_spec, "namespace", null), "default")
  image     = coalesce(lookup(local.job_spec, "image", null), "mysql:8.4")

  writer         = lookup(lookup(var.inputs.mysql, "interfaces", {}), "writer", {})
  db_host        = lookup(local.writer, "host", "")
  db_port        = coalesce(lookup(local.writer, "port", null), 3306)
  admin_user     = lookup(local.writer, "username", "")
  admin_password = lookup(local.writer, "password", "")

  base_name = substr("${var.instance_name}-${var.environment.unique_name}", 0, 40)

  # The job must re-run whenever the target instance or the desired state changes.
  # A Kubernetes Job is effectively immutable and a completed one is never re-run,
  # so without this a rebuilt database would silently end up with no user: terraform
  # would see an unchanged spec and leave the old, completed job in place. Folding a
  # hash of the host plus the desired state into the NAME forces a new job instead.
  state_hash = substr(sha256(jsonencode({
    host       = local.db_host
    user       = local.username
    host_scope = local.user_host
    plugin     = local.auth_plugin
    databases  = local.databases
    grants     = local.grants
  })), 0, 8)

  job_name    = "${local.base_name}-${local.state_hash}"
  secret_name = "${local.base_name}-${local.state_hash}-creds"

  tolerations = concat(
    var.environment.default_tolerations,
    try(var.inputs.kubernetes_cluster.attributes.legacy_outputs.facets_dedicated_tolerations, [])
  )

  # Rendered into the job's stdin via a heredoc, never into argv, so no secret ever
  # appears in the pod's command line or in `kubectl describe`. $${...} is escaped so
  # terraform emits a literal shell reference that bash expands at run time from the
  # environment, which is itself sourced from a Kubernetes secret.
  create_databases_sql = join("\n", [
    for db in local.databases : "CREATE DATABASE IF NOT EXISTS `${db}`;"
  ])

  grant_sql = join("\n", [
    for g in local.grants :
    "GRANT ${lookup(g, "privileges", "ALL PRIVILEGES")} ON `${g.database}`.* TO '$${USERNAME}'@'$${USER_HOST}';"
  ])

  sql_script = <<-EOT
    set -euo pipefail

    echo "provisioning on $${DB_HOST}:$${DB_PORT} as $${ADMIN_USER}"

    mysql --protocol=TCP -h "$${DB_HOST}" -P "$${DB_PORT}" -u "$${ADMIN_USER}" <<'PROBE'
    SELECT 1;
    PROBE

    mysql --protocol=TCP -h "$${DB_HOST}" -P "$${DB_PORT}" -u "$${ADMIN_USER}" <<SQL
    ${local.create_databases_sql}
    CREATE USER IF NOT EXISTS '$${USERNAME}'@'$${USER_HOST}' IDENTIFIED WITH ${local.auth_plugin} BY '$${USER_PASSWORD}';
    ALTER USER '$${USERNAME}'@'$${USER_HOST}' IDENTIFIED WITH ${local.auth_plugin} BY '$${USER_PASSWORD}';
    ${local.grant_sql}
    FLUSH PRIVILEGES;
    SQL

    echo "verifying the user exists with the requested plugin"
    mysql --protocol=TCP -h "$${DB_HOST}" -P "$${DB_PORT}" -u "$${ADMIN_USER}" -N -B <<SQL | grep -q "${local.auth_plugin}"
    SELECT plugin FROM mysql.user WHERE user='$${USERNAME}' AND host='$${USER_HOST}';
    SQL

    echo "done"
  EOT
}

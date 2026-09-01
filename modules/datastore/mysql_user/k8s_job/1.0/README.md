# MySQL User (k8s_job)

Creates MySQL databases and a dedicated least-privilege user on an **existing** MySQL
instance, then publishes the generated user credentials as outputs.

## Why a Kubernetes Job

MySQL users and databases are objects *inside* the server, so creating them needs a live
SQL connection at apply time. A managed instance is normally private, and the Terraform
runner has no route to it. This module therefore runs its SQL from a `kubernetes_job`
inside the cluster, which does have that route. Consequences:

- no MySQL Terraform provider is required, so RULE-013 is satisfied — the only provider
  needed is `kubernetes`, which `kubernetes_cluster` already exposes;
- it works against a private instance with no public access and no new networking.

## Why `auth_plugin` matters

The password-checking method is a **per-user** property. `authentication_policy` only
sets the default for newly created users, so one instance can serve both methods at once.

An instance created directly on MySQL 8.4 gets `caching_sha2_password` users. An instance
created on an older engine and upgraded in place keeps `mysql_native_password` users. An
application whose JDBC driver predates Connector/J 8.0 has no implementation of
`caching_sha2_password` and cannot authenticate to the former at all — the failure surfaces
as an SSL handshake error, not an auth error, which is badly misleading.

Set `auth_plugin: mysql_native_password` for those applications. It changes only this user.

## Idempotency and re-runs

All statements are `IF NOT EXISTS` / `ALTER`, so re-running is safe. A Kubernetes Job is
effectively immutable and a completed Job is never re-run, so the job **name** includes a
hash of the target host and the desired state. If the instance is rebuilt, or the user,
databases or grants change, the name changes and a fresh Job runs. Without this a rebuilt
database would silently end up with no user.

## Secret handling

- The user password is **generated** by the module. It is never accepted as input, so it
  cannot be committed to a blueprint.
- Credentials reach the Job only as environment variables sourced from a Kubernetes
  Secret. The admin password is passed via `MYSQL_PWD`, and all SQL goes in over
  **stdin**, so no secret appears in the pod's command line or in `kubectl describe`.
- `interfaces.user.connection_string` embeds the password and is therefore listed in
  `secrets` alongside it.

## Known limitations

- The Kubernetes Secret holding the credentials is **not** deleted after the Job
  completes; it persists in the namespace for the lifetime of the resource.
- `job.image` defaults to the floating tag `mysql:8.4`. Pin it to a digest for
  reproducibility — a floating tag can move or be withdrawn (see RULE-018).
- Only the first entry of `databases` is reported as `interfaces.user.database`.

## Example

```yaml
kind: mysql_user
flavor: k8s_job
version: '1.0'
spec:
  user:
    name: acs
    auth_plugin: mysql_native_password
    host: '%'
  databases:
    - access_control
  grants:
    - database: access_control
      privileges: ALL PRIVILEGES
```

Consuming service:

```
SPRING_DATASOURCE_USERNAME = ${mysql_user.acs.out.interfaces.user.username}
SPRING_DATASOURCE_PASSWORD = ${mysql_user.acs.out.interfaces.user.password}
```

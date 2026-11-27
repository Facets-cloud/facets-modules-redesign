# MySQL logical databases on Cloud SQL

This flavor manages logical databases on an existing Cloud SQL instance and can
manage a designated set of users on that instance. It does not create or resize
the physical instance. The cloud account supplies the Google provider, while
`source` references the physical MySQL output to establish a dependency and
provide connection endpoints.

```text
physical MySQL -> logical database resources
              -> one designated logical resource owns each shared username
sandbox secret -> same canonical username/password map for every logical resource
```

`cloud_sql_instance` must match the physical source's actual Cloud SQL instance
name. `databases_json` is a JSON list of databases owned by this logical
resource. Database names must be unique per physical host. `user_list` describes
the users exposed to consumers and their default databases. Exactly one logical
resource per physical host must list a given username in `managed_users`; every
resource uses the same secret JSON map in `canonical_passwords_json`. Duplicate
Terraform ownership causes conflicts. The source input and Cloud SQL name are
separate and must be checked together in the deployment plan.

The password map must be supplied through a secret reference, not literal
blueprint data. Credentials remain in Terraform state. Outputs mark passwords and
connection strings sensitive. When generated credentials are used in connection
strings, use URL-safe alphanumeric passwords. Removing a managed user abandons it
in Cloud SQL; removing a logical database destroys it, subject to provider policy.

**Access:** Cloud SQL API-created MySQL users receive broad `cloudsqlsuperuser`
privileges. This flavor does not restrict users to the declared databases and is
not suitable where database-level isolation is required. The intended deployment
must explicitly accept that behavior. Do not use it to consolidate production
without a separate access review.

The module emits `@facets/mysql` reader/writer endpoints from the physical source
and one interface for each declared `user_list` key. Per-user database selection
uses that user's configured database, then the source database, then the first
configured logical database. Cross-resource dependencies, secret provisioning,
and the single-owner user assignment must be validated before applying a plan.

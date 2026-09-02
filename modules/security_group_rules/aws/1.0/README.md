# Security Group Rules — AWS

Adds **additive ingress rules to existing AWS security groups**. It never creates
or owns a security group. Each rule is one `aws_vpc_security_group_ingress_rule`,
so rules created outside Terraform are never proposed for deletion. Scoped to a
transfer project so the rules are removed cleanly when the migration environment
is torn down.

- **Cloud:** aws
- **Input:** `@facets/aws_cloud_account`
- **Output type:** `@facets/security_group_rules`

---

## Architecture

```
   input: @facets/aws_cloud_account (aws provider)
                    │
                    ▼
   ┌──────────────────────────────────────────────┐
   │ security_group_rules (this module)            │
   │  for each entry in spec.rules:                 │
   │    aws_vpc_security_group_ingress_rule         │
   │      security_group_id  (existing sg-...)      │
   │      cidr_ipv4 = rule.cidr | source_cidr       │
   │      from_port = to_port = rule.port           │
   │      ip_protocol = tcp                          │
   └───────────────────────┬──────────────────────┘
                            │  attaches to (does NOT create)
                            ▼
   ┌──────────────────────────────────────────────┐
   │ EXISTING security group  sg-xxxxxxxx           │
   │   (in its VPC; other rules left untouched)     │
   │   + new ingress: tcp/<port> from <cidr>        │
   └──────────────────────────────────────────────┘
```

---

## Usage

```yaml
kind: security_group_rules
flavor: aws
version: "1.0"
disabled: false
spec:
  source_cidr: 10.60.0.0/16               # default CIDR for rules without their own
  rules:
    my-db-rule:                           # key: ^[a-zA-Z0-9_-]+$
      security_group_id: sg-0123456789abcdef0
      port: 5432
      description: GCP VPN                 # optional
    my-other-rule:
      security_group_id: sg-0123456789abcdef1
      port: 3306
      cidr: 10.0.0.0/16                   # optional per-rule CIDR override
```

Each rule requires `security_group_id` and `port`. When a rule omits `cidr` it
uses `source_cidr`. When it omits `description` the rule is stamped
`facets transfer: <rule-key>`.

---

## Inputs

| Input | Type | Provider | Purpose |
|-------|------|----------|---------|
| `cloud_account` | `@facets/aws_cloud_account` | `aws` | AWS role + region for creating the ingress rules on the target security groups. |

---

## Spec

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `source_cidr` | string | No | `10.60.0.0/16` | Default IPv4 source CIDR applied to rules that do not set their own. |
| `rules` | map(object) | **Yes** | — | Map of named rules (key pattern `^[a-zA-Z0-9_-]+$`). See per-rule fields below. |

Per-rule object (`rules.<name>`):

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `security_group_id` | string | **Yes** | Existing AWS security group ID to receive this additive ingress rule. Pattern `^sg-[0-9a-f]{8,17}$`. |
| `port` | integer | **Yes** | TCP port to allow from the source CIDR (1–65535). |
| `cidr` | string | No | IPv4 source CIDR override for this rule. Empty/unset falls back to `source_cidr`. |
| `description` | string | No | Free-text description stamped on the AWS ingress rule. Defaults to `facets transfer: <rule-key>`. |

All rules are TCP ingress.

---

## Outputs — `@facets/security_group_rules`

### Attributes

| Field | Type | Description |
|-------|------|-------------|
| `rule_ids` | map(string) | Map of rule key to the created AWS security group ingress rule ID. |

### Interfaces

None.

---

## Notes

- **Additive only, never owns a group.** Uses
  `aws_vpc_security_group_ingress_rule` (one rule per resource), which never
  reads the group's other rules into state. Rules created outside Terraform are
  never proposed for deletion. Inline `aws_security_group` ingress would own the
  whole group and delete anything not declared here — this module deliberately
  avoids that.
- **Existing groups only.** The `security_group_id` must already exist; this
  module does not create security groups.
- **Clean teardown.** Because each rule is its own resource scoped to the
  transfer environment, destroying the environment removes exactly the rules this
  module added and nothing else.
- **CIDR precedence.** A per-rule `cidr` wins; otherwise `source_cidr` applies.
- **Tags.** Each rule is tagged `Name = <env unique_name>-<rule-key>`,
  `managed-by = facets`, and `intent = <kind>`.
- **Pairs with `cross_cloud_vpn/gcp-aws`.** Typical use is opening RDS ports to
  the GCP VPN CIDR (`10.60.0.0/16`) that the VPN module does not touch.
```

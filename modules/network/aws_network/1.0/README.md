# network / aws_network 2.0

One module, three postures, one output contract.

| Posture | `subnets` plan | `imports.import_existing` | What happens |
|---|---|---|---|
| **Greenfield** | omitted | false | `cidrsubnets()` derives private /19 + public /24 + database /24 per AZ — identical to 1.0 |
| **Brownfield adopt** | declared | **true** | Every object adopted at its live id; topology, names and tags taken verbatim |
| **Replication (M3)** | declared | false | Same declared shape created fresh in a new region/CIDR/sizing |

Output is always `@facets/aws-vpc-details` — 12 attributes, no interfaces — so any
posture is a drop-in swap for any other as far as consumers are concerned.

## Field naming is a contract

Read this once and the rest of the schema is obvious.

| Suffix | Means | Example |
|---|---|---|
| `*_key` / `*_keys` | a reference to another **Layout entry by its map key** — never a name, never an AWS id | `subnets.pvt-3c.route_table_key: pvt-2c` |
| `import_id` | the live **AWS object this entry adopts**, on the entry itself | `subnets.pvt-3c.import_id: subnet-099…` |
| other `*_id` / `*_ids` | live AWS identifiers this module does not own | `security_group_ids`, `imports.vpc_id` |
| `additional_tags` | the **only** tag field that merges | added on top of environment tags |
| anything titled **(verbatim)** | **replaces** the computed value outright; `{}` means "genuinely no tags" | `subnets.pvt-3c.tags` |

The one rule that catches people: `additional_tags` merges, every `*_tags` and every
per-entry `tags` replaces. A plan entry that declares verbatim tags ignores
`additional_tags` completely.

## Every field is either configuration or adoption

Adoption fields exist for one reason — reproducing a live object byte-for-byte — and
they are **hidden until `imports.import_existing` is on**. Nothing you see in a
greenfield form is there for import's benefit.

| entry | configuration (always) | adoption (hidden until the toggle) |
|---|---|---|
| `subnets.<k>` | `availability_zone`, `cidr_block`, `tier`, `map_public_ip_on_launch`, `route_table_key`, `associate_route_table` | `name`, `tags`, `import_id` |
| `route_tables.<k>` | `is_main`, `routes` | `name`, `tags`, `import_id` |
| `nat_gateways.<k>` | `subnet_key` | `name`, `tags`, `eip_tags`, `import_id`, `eip_import_id` |
| `network_acl` | `manage_default`, `ingress`, `egress` | `tags` |
| `vpc_endpoints.pins.<k>` | `subnet_keys`, `route_table_keys`, `security_group_ids`, `private_dns_enabled` | `tags`, `import_id` |
| `vpc_endpoints.custom.<k>` | `service_name`, `endpoint_type`, `subnet_keys`, `security_group_ids`, `route_table_keys`, `private_dns_enabled` | `tags`, `import_id` |
| top level | everything else | `vpc_tags`, `internet_gateway_tags`, `imports.*` |

**The ids live on the entries they adopt, not in a parallel block.** An earlier design had
`imports.subnet_ids`, `imports.route_table_ids`, `imports.nat_gateway_ids`,
`imports.eip_allocation_ids` and `imports.vpc_endpoint_ids` — five maps whose keys had to
be typed a second time to mirror the plan exactly, policed by two validations that existed
only to catch a mismatch. Now a plan entry carries its own `import_id`, mismatch is not
expressible, and `imports` keeps only the three singletons that have no plan entry to sit
on: the VPC, its internet gateway, and its default network ACL.

`import_existing` is a **posture, not a one-shot flag**. Leave it on after the import: it
also holds back greenfield-only behaviour — endpoint creation, the module's endpoint
security group, and `aws_main_route_table_association`. Turning it off on an adopted VPC
would let the next apply create all three.

## Three layers

| Layer | Fields | Where it belongs |
|---|---|---|
| **Design** — how to *derive* a network | `auto_select_azs`, `availability_zones`, `nat_strategy`, `vpc_endpoints.enable_*`, `additional_tags` | **Blueprint.** Posture, identical across environments |
| **Layout** — state the topology instead of deriving it | `subnets`, `route_tables`, `nat_gateways`, `vpc_tags`, `internet_gateway_tags`, `vpc_endpoints.custom` | **Env override.** Every value is environment-specific: CIDRs, AZ names, live tags |
| **Layout, but env-agnostic** | `network_acl` | **Blueprint or override.** A hardening baseline can be written once for every environment |
| **Import** — identifiers for an existing VPC | `imports.*`, `vpc_endpoints.pins` | **Env override, and hidden until `imports.import_existing` is on** |

`x-ui-overrides-only` marks layer 2 and 3; `x-ui-visible-if` on
`spec.imports.import_existing` hides layer 3 until the brownfield toggle is on. The
Design layer stays visible always — it is what a new environment is built from.

**`x-ui-overrides-only` is enforced, not cosmetic** — the control plane strips those
fields out of the BLUEPRINT schema, so the blueprint form offers only
`auto_select_azs`, `nat_strategy`, `additional_tags`, `network_acl` and the 16
endpoint toggles. One consequence to know going in: **`vpc_cidr` is required by the
module but not settable in the blueprint**, so every environment must supply it as an
override before it can deploy. That is deliberate — two environments sharing a CIDR
can never peer, and that failure surfaces late and expensively.

`network_acl` is the one Layout field left un-gated: it depends on nothing else in the
plan, and a hardening baseline (deny SSH/RDP from `0.0.0.0/0`) is genuinely the same
in every environment.

## Collections are maps, never lists

Every collection an environment might want to *partially* change is a map, because
overrides deep-merge objects but **replace** arrays wholesale. A list would force an
environment to restate the entire set to change one element.

| collection | keyed by | what the key buys |
|---|---|---|
| `subnets`, `route_tables`, `nat_gateways` | stable address key | the Terraform address, so a rename is not a rebuild |
| `route_tables.<k>.routes` | **destination CIDR** | uniqueness within a table becomes unsayable-if-wrong rather than a duplicate-key crash at apply |
| `network_acl.ingress` / `.egress` | **AWS rule number** | already unique per direction, and already what decides evaluation order |
| `vpc_endpoints.pins` / `.custom` | endpoint key | same key as `enable_<key>`, `imports.vpc_endpoint_ids.<key>` and the TF address |

Only genuinely atomic lists stay lists: `availability_zones`, `subnet_keys`,
`route_table_keys`, `security_group_ids`.

Rule numbers are map keys, so they are strings, and they are zero-padded before
sorting inside the module — otherwise `"100"` would order before `"50"`.

Declaring a Layout makes the Design layer's derivation knobs inert: `auto_select_azs`,
`availability_zones` and `nat_strategy` only ever shape the *derived* plan, so once
`subnets` is declared they are dead weight and should be omitted from the override.

That layering is what makes replication possible: take an adopt config, drop the
`imports` block, change `vpc_cidr`, and you have a new environment shaped like
the old one.

## Deliberately not in this module

| | Owned by |
|---|---|
| VPC peering connections **and their routes** | `vpc_peering` module |
| Security groups for workloads | the consuming module |
| `k8s-*` load balancers and their SGs | AWS Load Balancer Controller |
| Gateway-endpoint prefix-list routes | `aws_vpc_endpoint.route_table_ids` |
| `local` routes | AWS — implicit, never importable |

Route `target_type` is therefore limited to `internet_gateway` and `nat_gateway`:
the only gateways this module owns. A `nat_gateway` route names its gateway with
`nat_gateway_key`; an `internet_gateway` route needs no target at all.

## Known exceptions (3)

- **E2 — endpoint toggle defaults invert under `import_existing`.** The schema
  shows 1.0's `true` defaults, but adoption flips the effective default to
  `false` so it never creates an endpoint on a live VPC. Explicit values always
  win. Consequence: the UI shows defaults that are not in force during adoption.
- **E5 — adopted AWS-service endpoints need `vpc_endpoints.pins`.** The `enable_*`
  toggles derive subnets (all private), security group (the module's own) and tags.
  A hand-placed endpoint matches none of that, so `pins.<endpoint_key>` takes
  `subnet_keys`, `route_table_keys`, `security_group_ids`, `private_dns_enabled` and
  verbatim `tags`. Unset fields still derive. Brownfield-only, hence gated on the
  import toggle. The `custom` (PrivateLink) collection never needed this — it has
  always taken its attributes explicitly.
- **E4 — `aws_main_route_table_association` is greenfield-only.** The resource is
  not importable and main-ness already exists on an adopted VPC. It *is* required
  for replication, or subnets with `associate_route_table: false` would inherit a
  fresh empty main table and blackhole.

## Upgrading a 1.0 environment

`moved.tf` covers the resource re-keying. **It is not sufficient on its own** —
1.0 declared routes *inline* inside `aws_route_table`, and inline routes are
attributes, not resources, so they cannot be `moved` into `aws_route`. Each 1.0
environment must import its existing routes first or the upgrade hits
`RouteAlreadyExists`:

```
terraform import 'aws_route.this["public|0.0.0.0/0"]' <rtb-id>_0.0.0.0/0
```

Prove this on a throwaway environment before rolling 2.0 to existing users. New
environments and adoptions are unaffected.

**The spec surface also changed between 1.0 and 2.0.** `moved.tf` cannot help with
this — a 1.0 tfvars must be rewritten:

| 1.0 | 2.0 |
|---|---|
| `nat_gateway: {strategy: single}` | `nat_strategy: single` |
| `tags: {...}` | `additional_tags: {...}` |
| `vpc_endpoints.enable_*` | unchanged |

Everything else in 2.0's spec is new — 1.0 had no declared plan, no imports section and
no network ACL support, so there is nothing to migrate there.

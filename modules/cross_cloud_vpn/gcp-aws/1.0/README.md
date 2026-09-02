# Cross-Cloud VPN — GCP to AWS (HA)

A **highly-available IPsec VPN** between one GCP VPC and one AWS VPC. On the GCP
side it provisions an HA VPN gateway, a Cloud Router, four VPN tunnels, and their
BGP router interfaces and peers. On the AWS side it provisions two customer
gateways, an optional Virtual Private Gateway (VGW), two VPN connections
(two tunnels each), and route propagation onto the database subnets' route
tables. Both sides exchange routes dynamically over BGP.

- **Clouds:** gcp, aws
- **Inputs:** `@facets/gcp_cloud_account`, `@facets/aws_cloud_account`
- **Output type:** `@facets/cross_cloud_vpn`

---

## Architecture

```
        GCP side                          4 tunnels                    AWS side
  ┌──────────────────────────┐         (2 per AWS conn)      ┌──────────────────────────┐
  │ HA VPN Gateway           │                               │ Virtual Private Gateway  │
  │   interface 0 ───────────┼── tun 0 ═══ VPN connection 0 ═╪══ VGW (created or reused) │
  │   interface 0 ───────────┼── tun 1 ═══      (2 tunnels)  │                          │
  │   interface 1 ───────────┼── tun 2 ═══ VPN connection 1 ═╪══ attached to AWS VPC    │
  │   interface 1 ───────────┼── tun 3 ═══      (2 tunnels)  │                          │
  │                          │                               │ 2x Customer Gateway      │
  │ Cloud Router (BGP)       │◄──────── BGP peering ────────►│   (point at GCP HA VPN   │
  │   ASN gcp_router_asn     │   advertise gcp_cidr /        │    interface IPs)        │
  │   advertises gcp_cidr    │   learn aws_cidrs             │   ASN aws_vgw_asn        │
  │                          │                               │                          │
  │ Firewall: allow AWS      │                               │ Route propagation onto   │
  │  CIDRs -> DB ports+ICMP  │                               │  db_subnet_ids' tables   │
  └────────────┬─────────────┘                               └─────────────┬────────────┘
               │                                                            │
   input: @facets/gcp_cloud_account                        input: @facets/aws_cloud_account
      (google provider)                                          (aws provider)
```

---

## Usage

```yaml
kind: cross_cloud_vpn
flavor: gcp-aws
version: "1.0"
disabled: false
spec:
  gcp_project_id: my-project              # empty -> gcp_cloud_account project
  gcp_region: us-central1                 # empty -> gcp_cloud_account region
  gcp_vpc_self_link: https://www.googleapis.com/compute/v1/projects/my-project/global/networks/my-vpc
  gcp_cidr: 10.60.0.0/16                  # advertised to AWS over BGP
  aws_vpc_id: vpc-0123456789abcdef0
  aws_cidrs:
    - 10.0.0.0/16
    - 10.1.0.0/16
  db_subnet_ids:                          # every subnet whose DBs must be reachable
    - subnet-0123456789abcdef0
    - subnet-0123456789abcdef1
  existing_vgw_id: ""                     # empty -> create + attach a new VGW
  gcp_router_asn: 65001
  aws_vgw_asn: 64512
  allowed_tcp_ports:
    - 5432
    - 3306
  mtu: 1436
  name_prefix: ""                         # empty -> derived from env + resource name
```

Only `gcp_vpc_self_link` and `aws_vpc_id` are required; every other field has a
default.

---

## Inputs

| Input | Type | Provider | Purpose |
|-------|------|----------|---------|
| `gcp_cloud_account` | `@facets/gcp_cloud_account` | `google` | GCP project + region + credentials for the HA VPN gateway, Cloud Router, tunnels, and firewall. |
| `aws_cloud_account` | `@facets/aws_cloud_account` | `aws` | AWS role + region for the VGW, customer gateways, VPN connections, and route propagation. |

---

## Spec

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `gcp_project_id` | string | No | `""` | GCP project that owns the HA VPN gateway and Cloud Router. Empty uses the GCP cloud account project. |
| `gcp_region` | string | No | `""` | GCP region for the HA VPN gateway and Cloud Router. Empty uses the GCP cloud account region. |
| `gcp_vpc_self_link` | string | **Yes** | — | Self link of the GCP VPC to connect. |
| `gcp_cidr` | string | No | `10.60.0.0/16` | GCP VPC CIDR advertised to AWS over BGP. |
| `aws_vpc_id` | string | **Yes** | — | AWS VPC ID to attach or reuse a VGW for. Pattern `^vpc-[a-z0-9]+$`. |
| `aws_cidrs` | array(string) | No | `[10.0.0.0/16, 10.1.0.0/16]` | AWS VPC CIDRs allowed through the GCP firewall and learned over BGP. |
| `db_subnet_ids` | array(string) | No | 6 stage subnets | Every subnet in every DB subnet group whose databases must be reachable; VGW route propagation is enabled on their route tables. |
| `existing_vgw_id` | string | No | `""` | Existing AWS VGW ID. Empty creates and attaches a new VGW. Pattern `^(|vgw-[a-z0-9]+)$`. |
| `gcp_router_asn` | integer | No | `65001` | Private BGP ASN for the GCP Cloud Router (64512–65534). |
| `aws_vgw_asn` | integer | No | `64512` | Private BGP ASN for the AWS VGW side (64512–65534). Must differ from `gcp_router_asn`. |
| `allowed_tcp_ports` | array(integer) | No | `[5432, 3306]` | TCP ports allowed from AWS CIDRs into the GCP VPC. |
| `mtu` | integer | No | `1436` | Effective tunnel MTU to plan for cross-cloud transfers (1280–1460). |
| `name_prefix` | string | No | `""` | Cloud resource name prefix. Empty derives from the Facets environment and resource name. |

Validation: `gcp_router_asn` and `aws_vgw_asn` must be different; `mtu` must be
between 1280 and 1460.

---

## Outputs — `@facets/cross_cloud_vpn`

### Attributes

| Field | Type | Description |
|-------|------|-------------|
| `gcp_ha_vpn_gateway_name` | string | Name of the GCP HA VPN gateway. |
| `gcp_router_name` | string | Name of the GCP Cloud Router. |
| `gcp_router_asn` | number | BGP ASN configured on the GCP Cloud Router. |
| `aws_vpn_gateway_id` | string | AWS Virtual Private Gateway ID used by the VPN. |
| `aws_vpn_gateway_asn` | number | BGP ASN configured for the AWS VGW side. |
| `aws_customer_gateway_ids` | array(string) | AWS Customer Gateway IDs, one per GCP HA VPN gateway interface. |
| `aws_vpn_connection_ids` | array(string) | AWS VPN connection IDs, two connections for HA VPN. |
| `gcp_vpn_tunnel_names` | array(string) | GCP VPN tunnel names, four tunnels total. |
| `aws_route_table_ids` | array(string) | AWS route table IDs serving the DB subnets with VGW propagation enabled. |
| `aws_cidrs` | array(string) | AWS VPC CIDRs advertised over BGP. |
| `gcp_cidr` | string | GCP VPC CIDR advertised to AWS. |
| `mtu` | number | Effective tunnel MTU to plan for application transfers. |

### Interfaces

None.

---

## Notes

- **HA / redundancy.** Four tunnels total: the GCP HA VPN gateway has two
  interfaces, each carrying two tunnels to one of the two AWS VPN connections.
  The AWS external gateway on the GCP side uses `FOUR_IPS_REDUNDANCY`.
- **BGP.** Both sides run dynamic routing. The Cloud Router advertises `gcp_cidr`
  in `CUSTOM` mode and learns the AWS CIDRs over BGP. AWS connections use
  `static_routes_only = false` with IKEv2. The two ASNs must differ.
- **VGW reuse.** Set `existing_vgw_id` when the AWS VPC already has an attached
  VGW; leave it empty to create and attach a new one. A VPC cannot hold two VGW
  attachments.
- **AWS return routing.** The module reads the route tables behind
  `db_subnet_ids` and enables `aws_vpn_gateway_route_propagation` on each
  distinct table. This is required for AWS return traffic to reach `gcp_cidr`.
  List every subnet in every DB subnet group that must be reachable.
- **Firewall scope.** One GCP ingress rule opens `allowed_tcp_ports` (default TCP
  5432, 3306) plus ICMP from the AWS CIDRs. It does not open all ports.
- **AWS security groups are not touched.** RDS security groups must separately
  allow `gcp_cidr` (default `10.60.0.0/16`). This module does not modify AWS
  security groups because that is a live production change. See the companion
  `security_group_rules/aws` module.
- **MTU.** Default effective MTU is 1436. If small queries work but large
  transfers hang, clamp TCP MSS on the path or clients.
- **Lifecycle.** No `prevent_destroy` and no `lifecycle.ignore_changes` — this is
  temporary transfer infrastructure meant to be torn down.
```

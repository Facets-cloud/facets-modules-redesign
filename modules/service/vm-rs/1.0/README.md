# service / vm-rs (GCP)

A VM-backed **service**, modelled with **Deployment / StatefulSet** semantics but backed by raw GCE
VMs instead of pods. One Facets resource = one logical service (a set of replicas).

- **Deployment** — stateless / fungible replicas.
- **StatefulSet** — stable per-replica identity + per-replica persistent volume(s), zonal or regional PD.

## Dual mode

| mode | how | result |
|------|-----|--------|
| **Greenfield** | leave `imports` empty | provisions fresh VMs (+ disks); names derive `{service}-{ordinal}`, IPs ephemeral |
| **Import / adopt** | set `imports.*` pins (names, internal IPs, disk names) | adopts an existing hand-rolled VM set **0-change** (`ignore_changes` on the volatile/computed attributes) |

## Inputs
- `cloud_account` (`@facets/gcp_cloud_account`) — the GCP project.
- `network_details` (`@facets/gcp-network-details`) — VPC / subnet. Subnetwork is derived per-replica from the zone's region.

## Key spec
`type` · `machine_type` · `replicas_json` (per-replica zones) · `boot_image` (artifact-bindable) ·
`data_volumes_json` (zonal PD) · `regional_disks_json` (replicated PD) · shielded / scheduling / SA scopes ·
`imports` (adoption pins). Output: `@facets/service`.

The boot image is an `artifact_inputs.primary` bound to `spec.boot_image`, so a Packer/GCE image built
by CI drives the release (build → set-artifact-uri → release replaces the VM). Import resources bind no
artifact and keep their live image (ignored).

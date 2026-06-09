# Vultr Object Storage

Creates an S3-compatible object storage subscription on Vultr and exposes its endpoint and access credentials. Produces `@facets/vultr-object-storage`.

## Overview

Unlike AWS S3 or Linode object storage (where the module creates a *bucket*), a Vultr object storage subscription is a **whole S3 endpoint** with its own access/secret key pair. Buckets are created against it via the S3 API by the consuming application. The subscription is region-scoped via the object storage cluster, resolved from the requested region.

## Resources Created

- **vultr_object_storage**: An S3-compatible object storage subscription (endpoint + keys)
- **data.vultr_object_storage_cluster**: Resolves the object storage cluster for the region

## Required Configuration

- **Region**: Vultr object storage region selecting the cluster, e.g. `ewr`, `ord`, `ams`
- **Storage Tier** (`tier_id`, optional): object storage tier ID (1 = Standard); list via `GET /v2/object-storage/tiers`

## Inputs

- **Vultr Cloud Account** (`@facets/vultr_cloud_account`): provides the Vultr provider

## Outputs

- `@facets/vultr-object-storage` (default): `object_storage_id`, `label`, `region`, `cluster_id`, `s3_endpoint`, `s3_url`, `access_key`, `secret_key`

## Security Considerations

- `access_key` and `secret_key` are declared in the `secrets` output so the platform treats them as sensitive.

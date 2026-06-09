# Linode Object Storage

Creates an S3-compatible object storage bucket on Linode (Akamai) and a scoped access key. Produces the `@facets/linode-object-storage` output type.

## Overview

Provisions a bucket plus a read/write access key restricted to that bucket. The output exposes the S3-compatible endpoint and credentials so applications can connect via any S3 client. Object storage on Linode is region/cluster-scoped, so the region is an override-only field.

> Note: `@facets/s3` (the AWS contract) models IRSA-based access and carries no credentials, so it is not a good fit for Linode. This module follows the OVH precedent and exposes S3-compatible credentials directly via a Linode-specific output type.

## Resources Created

- **linode_object_storage_bucket**: The S3-compatible bucket
- **linode_object_storage_key**: A read/write access key scoped to the bucket

## Required Configuration

- **Region** (override-only): object storage region (default `us-east`)
- **ACL**: canned ACL (default `private`)
- **Versioning / CORS** (optional): toggles

## Inputs

- **Linode Cloud Account** (`@facets/linode_cloud_account`): provides the Linode provider

## Outputs

- `@facets/linode-object-storage`: `bucket_id`, `bucket_name`, `region`, `s3_endpoint`, `bucket_url`, `access_key`, `secret_key`

# Linode (Akamai) Provider Configuration

Configures the Linode Terraform provider with API token authentication for use by other Linode modules.

## Overview

This module establishes the foundational Linode (Akamai Cloud) provider configuration using a Linode Personal Access Token (PAT). It serves as the base provider configuration that other Linode infrastructure modules (VPC, LKE, Object Storage, Managed Database) consume to access Linode APIs and provision resources. It produces the `@facets/linode_cloud_account` output type.

## Environment as Dimension

**Environment-specific provider configuration**: The API token is a secret reference and the default region is an override-only field, allowing different Linode credentials and regions per environment.

## Resources Created

- **Linode Provider Configuration**: Establishes an authenticated connection to the Linode API
- **Provider Output Interface**: Exposes the configured provider and default region for consumption by other modules

## Security Considerations

- The API token is supplied via a secret reference and is never stored in plain text within the module configuration
- The token is declared in the `secrets` output attribute so the platform treats it as sensitive
- Provider configuration is scoped per environment for security isolation

## Required Configuration

- **Linode API Token**: A Linode Personal Access Token with read/write scopes (secret reference)
- **Linode Region**: The default region for downstream resources, e.g. `us-east`, `us-ord`, `eu-west`, `ap-south` (override-only)

## Usage Notes

This module does not create any actual Linode resources — it only configures the provider authentication. Other Linode modules should consume this module's `@facets/linode_cloud_account` output to access Linode services with proper authentication.

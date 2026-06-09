# Vultr Provider Configuration

Configures the Vultr Terraform provider with API key authentication for use by other Vultr modules.

## Overview

This module establishes the foundational Vultr provider configuration using a Vultr API key. It serves as the base provider configuration that other Vultr infrastructure modules (VPC, VKE, Object Storage, Managed Database) consume to access Vultr APIs and provision resources. It produces the `@facets/vultr_cloud_account` output type.

## Environment as Dimension

**Environment-specific provider configuration**: The API key is a secret reference and the default region is an override-only field, allowing different Vultr credentials and regions per environment.

## Resources Created

- **Vultr Provider Configuration**: Establishes an authenticated connection to the Vultr API
- **Provider Output Interface**: Exposes the configured provider and default region for consumption by other modules

## Security Considerations

- The API key is supplied via a secret reference and is never stored in plain text within the module configuration
- The key is declared in the `secrets` output attribute so the platform treats it as sensitive
- Provider configuration is scoped per environment for security isolation

## Required Configuration

- **Vultr API Key**: A Vultr API key with access to the resources you intend to manage (secret reference)
- **Vultr Region**: The default region for downstream resources, e.g. `ewr`, `lax`, `ord`, `fra`, `sgp` (override-only)

## Usage Notes

This module does not create any actual Vultr resources — it only configures the provider authentication. Other Vultr modules should consume this module's `@facets/vultr_cloud_account` output to access Vultr services with proper authentication.

# OVH Provider Configuration

Configures OVH Terraform provider with application key authentication for use by other OVH modules.

## Overview

This module establishes the foundational OVH provider configuration using application key, secret, and consumer key authentication. It serves as the base provider configuration that other OVH infrastructure modules can consume to access OVH APIs and services.

## Environment as Dimension  

**Environment-specific provider configuration**: Credentials (application_key, application_secret, consumer_key) are configured as override-only fields, allowing different OVH API credentials per environment. The API endpoint selection remains consistent across environments unless specifically overridden.

## Resources Created

- **OVH Provider Configuration**: Establishes authenticated connection to OVH APIs
- **Provider Output Interface**: Exposes configured provider for consumption by other modules

## Security Considerations

- All credential fields use secret references and are marked as override-only
- Credentials are never stored in plain text within the module configuration
- Provider configuration is scoped per environment for security isolation

## Required Configuration

- **API Endpoint**: Select appropriate OVH region (ovh-eu, ovh-us, ovh-ca, etc.)
- **Application Key**: Your OVH API application key (override-only)
- **Application Secret**: Your OVH API application secret (override-only) 
- **Consumer Key**: Your OVH API consumer key (override-only)

## Usage Notes

This module does not create any actual OVH resources - it only configures the provider authentication. Other OVH modules should consume this module's output to access OVH services with proper authentication.
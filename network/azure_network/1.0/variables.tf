#########################################################################
# Facets Module Variables                                               #
#                                                                       #
# Auto-injected variables that every Facets module receives             #
#########################################################################

variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.instance_name))
    error_message = "Instance name must contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })

  validation {
    condition     = can(var.environment.name) && can(var.environment.unique_name) && can(var.environment.cloud_tags)
    error_message = "Environment must contain name, unique_name, and cloud_tags."
  }
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type        = any
  default     = {}
}

#########################################################################
# Instance Configuration Schema                                         #
#                                                                       #
# Simplified schema for fixed subnet allocation                        #
#########################################################################

variable "instance" {
  description = "The resource instance configuration"
  type = object({
    spec = object({
      # Core VNet Configuration
      vnet_cidr          = string
      region             = string
      availability_zones = list(string)

      # NAT Gateway Configuration
      nat_gateway = object({
        strategy = string
      })

      # Additional Tags
      tags = optional(map(string), {})
    })
  })

  #########################################################################
  # VNet CIDR Validation - Only /16 networks allowed                     #
  #########################################################################
  validation {
    condition     = can(cidrhost(var.instance.spec.vnet_cidr, 0))
    error_message = "VNet CIDR must be a valid CIDR block."
  }

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/16$", var.instance.spec.vnet_cidr))
    error_message = "VNet CIDR must be a /16 network (e.g., 10.0.0.0/16)."
  }

  #########################################################################
  # Region Validation                                                     #
  #########################################################################
  validation {
    condition     = length(var.instance.spec.region) > 0
    error_message = "Azure region cannot be empty."
  }

  validation {
    condition = contains([
      "eastus", "eastus2", "southcentralus", "westus2", "westus3", "australiaeast",
      "southeastasia", "northeurope", "swedencentral", "uksouth", "westeurope",
      "centralus", "southafricanorth", "centralindia", "eastasia", "japaneast",
      "koreacentral", "canadacentral", "francecentral", "germanywestcentral",
      "norwayeast", "switzerlandnorth", "uaenorth", "brazilsouth", "eastus2euap",
      "qatarcentral", "centralusstage", "eastusstage", "eastus2stage", "northcentralusstage",
      "southcentralusstage", "westusstage", "westus2stage", "asia", "asiapacific",
      "australia", "brazil", "canada", "europe", "france", "germany", "global",
      "india", "japan", "korea", "norway", "singapore", "southafrica", "switzerland",
      "uae", "uk", "unitedstates"
    ], var.instance.spec.region)
    error_message = "Region must be a valid Azure region name."
  }

  #########################################################################
  # Availability Zones Validation                                         #
  #########################################################################
  validation {
    condition     = length(var.instance.spec.availability_zones) >= 1 && length(var.instance.spec.availability_zones) <= 3
    error_message = "Availability zones must contain between 1 and 3 zones."
  }

  validation {
    condition = alltrue([
      for zone in var.instance.spec.availability_zones :
      contains(["1", "2", "3"], zone)
    ])
    error_message = "Availability zones must be \"1\", \"2\", or \"3\"."
  }

  #########################################################################
  # NAT Gateway Strategy Validation                                       #
  #########################################################################
  validation {
    condition = contains([
      "single", "per_az"
    ], var.instance.spec.nat_gateway.strategy)
    error_message = "NAT Gateway strategy must be either 'single' or 'per_az'."
  }
}

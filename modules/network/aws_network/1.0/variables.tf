variable "instance_name" {
  description = "Name of the instance"
  type        = string
}

variable "environment" {
  description = "Environment configuration"
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "Input references from other modules"
  type = object({
    cloud_account = object({
      attributes = optional(object({
        aws_iam_role = optional(string)
        aws_region   = optional(string)
        external_id  = optional(string)
        session_name = optional(string)
      }))
      interfaces = optional(object({}))
    })
  })
}

variable "instance" {
  description = "Instance configuration"
  type        = any

  # ── 1.0 validations, preserved verbatim ──────────────────────────────────

  validation {
    condition     = try(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/16$", lookup(var.instance.spec, "vpc_cidr", "")), false) != false
    error_message = "VPC CIDR must be a /16 block (e.g., 10.0.0.0/16) for optimal Kubernetes workloads."
  }

  # AZ count only constrains the DERIVED path. A declared subnet plan carries its own AZs.
  validation {
    condition = (
      length(lookup(var.instance.spec, "subnets", {})) > 0 ||
      lookup(var.instance.spec, "auto_select_azs", true) == true ||
      (
        length(lookup(var.instance.spec, "availability_zones", [])) >= 2 &&
        length(lookup(var.instance.spec, "availability_zones", [])) <= 5
      )
    )
    error_message = "When auto_select_azs is false and no subnet plan is declared, specify between 2 and 5 availability zones."
  }

  validation {
    condition = (
      lookup(var.instance.spec, "auto_select_azs", true) == true ||
      length(lookup(var.instance.spec, "availability_zones", [])) == 0 ||
      alltrue([
        for az in lookup(var.instance.spec, "availability_zones", []) :
        can(regex("^[a-z]{2}-[a-z]+-[0-9][a-z]$", az))
      ])
    )
    error_message = "When specified, availability zones must be in format like 'us-east-1a'."
  }

  validation {
    condition     = contains(["single", "per_az"], lookup(var.instance.spec, "nat_strategy", "single"))
    error_message = "nat_strategy must be either 'single' or 'per_az'."
  }

  validation {
    condition     = try(alltrue([for k, v in lookup(var.instance.spec, "additional_tags", {}) : can(tostring(v))]), true)
    error_message = "All tag values must be strings."
  }

  validation {
    condition = try(
      alltrue([for k in keys(lookup(var.instance.spec, "additional_tags", {})) : !contains(["Name", "Environment"], k)]),
      true
    )
    error_message = "Tag keys 'Name' and 'Environment' are reserved and will be overridden by the module."
  }

  # ── 2.0 validations: the declared plan ───────────────────────────────────

  # The plan is all-or-nothing. A half-declared plan is the one hybrid this module refuses.
  validation {
    condition = (
      (length(lookup(var.instance.spec, "subnets", {})) == 0 && length(lookup(var.instance.spec, "route_tables", {})) == 0) ||
      (length(lookup(var.instance.spec, "subnets", {})) > 0 && length(lookup(var.instance.spec, "route_tables", {})) > 0)
    )
    error_message = "Declare both 'subnets' and 'route_tables' together, or neither. A partially declared plan is not supported."
  }

  # Every subnet's route_table_key must name a declared route table.
  validation {
    condition = try(alltrue([
      for k, s in lookup(var.instance.spec, "subnets", {}) :
      contains(keys(lookup(var.instance.spec, "route_tables", {})), lookup(s, "route_table_key", ""))
      if lookup(s, "route_table_key", "") != ""
    ]), true)
    error_message = "Every subnet's 'route_table_key' must be a key present in the route_tables plan."
  }

  # Every NAT gateway must sit in a declared subnet, and that subnet must be public.
  validation {
    condition = try(alltrue([
      for k, n in lookup(var.instance.spec, "nat_gateways", {}) :
      lookup(lookup(lookup(var.instance.spec, "subnets", {}), n.subnet_key, {}), "tier", "") == "public"
    ]), true)
    error_message = "Every nat_gateways entry's 'subnet_key' must name a plan subnet whose tier is 'public'."
  }

  # A nat_gateway route must name a declared NAT gateway.
  validation {
    condition = try(alltrue(flatten([
      for rk, rt in lookup(var.instance.spec, "route_tables", {}) : [
        for dest, r in lookup(rt, "routes", {}) :
        contains(keys(lookup(var.instance.spec, "nat_gateways", {})), lookup(r, "nat_gateway_key", ""))
        if lookup(r, "target_type", "") == "nat_gateway"
      ]
    ])), true)
    error_message = "Routes with target_type 'nat_gateway' must set 'nat_gateway_key' to a key from the nat_gateways plan."
  }

  # At most one route table may claim to be the VPC main route table.
  validation {
    condition = length([
      for k, rt in lookup(var.instance.spec, "route_tables", {}) : k if lookup(rt, "is_main", false)
    ]) <= 1
    error_message = "At most one route table may set is_main = true."
  }

  # ── 2.0 validations: imports ─────────────────────────────────────────────

  # Adoption requires the plan — IDs alone cannot describe a topology.
  validation {
    condition = (
      try(var.instance.spec.imports.import_existing, false) == false ||
      length(lookup(var.instance.spec, "subnets", {})) > 0
    )
    error_message = "import_existing requires a declared subnet plan; the imports block carries identifiers only."
  }

  # Adoption ids live ON the plan entry they adopt, so there is no key set to
  # reconcile - only completeness to check.
  validation {
    condition = (
      try(var.instance.spec.imports.import_existing, false) == false ||
      alltrue([
        for k, s in lookup(var.instance.spec, "subnets", {}) :
        can(regex("^subnet-[0-9a-f]{8,17}$", lookup(s, "import_id", "")))
      ])
    )
    error_message = "When importing, every subnet plan entry needs its own import_id."
  }

  validation {
    condition = (
      try(var.instance.spec.imports.import_existing, false) == false ||
      alltrue([
        for k, rt in lookup(var.instance.spec, "route_tables", {}) :
        can(regex("^rtb-[0-9a-f]{8,17}$", lookup(rt, "import_id", "")))
      ])
    )
    error_message = "When importing, every route_tables plan entry needs its own import_id."
  }

  validation {
    condition = (
      try(var.instance.spec.imports.import_existing, false) == false ||
      alltrue([
        for k, n in lookup(var.instance.spec, "nat_gateways", {}) :
        can(regex("^nat-[0-9a-f]{8,17}$", lookup(n, "import_id", ""))) &&
        can(regex("^eipalloc-[0-9a-f]{8,17}$", lookup(n, "eip_import_id", "")))
      ])
    )
    error_message = "When importing, every nat_gateways plan entry needs import_id and eip_import_id."
  }

  validation {
    condition = (
      try(var.instance.spec.imports.import_existing, false) == false ||
      try(can(regex("^vpc-[0-9a-f]{8,17}$", var.instance.spec.imports.vpc_id)), false)
    )
    error_message = "When import_existing is true, imports.vpc_id is required and must be a valid VPC id."
  }

  # Adopting the default NACL means an import block has to name it, so the id belongs
  # in the spec even though the resource itself derives its id from the VPC.
  validation {
    condition = (
      try(var.instance.spec.imports.import_existing, false) == false ||
      try(var.instance.spec.network_acl.manage_default, false) == false ||
      try(can(regex("^acl-[0-9a-f]{8,17}$", var.instance.spec.imports.network_acl_id)), false)
    )
    error_message = "When importing a VPC whose default network ACL is managed, imports.network_acl_id is required."
  }
}

# Anycloud kubernetes_cluster: branch on the cloud_provider published by the LINKED cloud_account.
locals {
  cloud_provider = var.inputs.cloud_account.attributes.cloud_provider
  is_aws         = local.cloud_provider == "AWS"
  is_gcp         = local.cloud_provider == "GCP"

  spec = var.instance.spec

  # common fields (defensive: Facets does not inject schema defaults into var.instance.spec)
  cluster_version = try(local.spec.cluster_version, "1.30")

  # cluster name — the name of the cluster actually created on the active cloud
  # (GKE needs a letter-first name, see name.tf)
  cluster_name = local.is_aws ? local.resource_name : local.gke_cluster_name

  # Default system node pool — created WITH the cluster only when enabled. Off by default →
  # control-plane-only cluster (count-gated to 0). The linked cloud_account's cloud_provider decides
  # which pool is made (EKS managed node group vs GKE node pool); there is no second cloud switch.
  default_pool         = try(local.spec.default_node_pool, {})
  default_pool_enabled = try(local.default_pool.enabled, false)
  aws_default_pool     = local.is_aws && local.default_pool_enabled
  gcp_default_pool     = local.is_gcp && local.default_pool_enabled

  dp_aws = try(local.default_pool.aws, {})
  dp_gcp = try(local.default_pool.gcp, {})

  # AWS default node group config (defensive reads; defaults mirror the nodepool module)
  dp_aws_instance_type  = try(local.dp_aws.instance_type, "t3.medium")
  dp_aws_instance_types = length(try(local.dp_aws.instance_types, [])) > 0 ? local.dp_aws.instance_types : [local.dp_aws_instance_type]
  dp_aws_capacity_type  = try(local.dp_aws.capacity_type, "ON_DEMAND")
  # AMI arch auto-derives from the instance family unless ami_type is set explicitly: Graviton
  # families (t4g/c6g/c7g/m7g/r8g … — 'g' right after the generation digits) → arm64, else x86_64.
  dp_aws_is_graviton     = can(regex("^[a-z]+[0-9]+g", local.dp_aws_instance_types[0]))
  dp_aws_ami_explicit    = trimspace(try(local.dp_aws.ami_type, ""))
  dp_aws_ami_type        = local.dp_aws_ami_explicit != "" ? local.dp_aws_ami_explicit : (local.dp_aws_is_graviton ? "AL2023_ARM_64_STANDARD" : "AL2023_x86_64_STANDARD")
  dp_aws_disk_size       = try(local.dp_aws.disk_size_gb, 50)
  dp_aws_min_size        = try(local.dp_aws.min_size, 1)
  dp_aws_max_size        = try(local.dp_aws.max_size, 3)
  dp_aws_desired_size    = try(local.dp_aws.desired_size, 2)
  dp_aws_max_unavailable = try(local.dp_aws.max_unavailable, 1)
  # Optional AZ pinning: restrict the system node group to a subset of the VPC's private subnets.
  dp_aws_pin_azs = try(local.dp_aws.availability_zones, [])

  # GCP default node pool config
  dp_gcp_machine_type = try(local.dp_gcp.machine_type, "e2-medium")
  dp_gcp_disk_type    = try(local.dp_gcp.disk_type, "pd-balanced")
  dp_gcp_disk_size    = try(local.dp_gcp.disk_size_gb, 100)
  dp_gcp_spot         = try(local.dp_gcp.spot, false)
  dp_gcp_autoscaling  = try(local.dp_gcp.autoscaling_enabled, true)
  dp_gcp_min_nodes    = try(local.dp_gcp.min_node_count, 1)
  dp_gcp_max_nodes    = try(local.dp_gcp.max_node_count, 3)
  dp_gcp_image_type   = try(local.dp_gcp.image_type, "COS_CONTAINERD")
  dp_gcp_auto_repair  = try(local.dp_gcp.auto_repair, true)
  dp_gcp_auto_upgrade = try(local.dp_gcp.auto_upgrade, true)
  dp_gcp_max_surge    = try(local.dp_gcp.upgrade_max_surge, 1)
  dp_gcp_max_unavail  = try(local.dp_gcp.upgrade_max_unavailable, 0)
  dp_gcp_max_pods     = try(local.dp_gcp.max_pods_per_node, 110)
  dp_gcp_secure_boot  = try(local.dp_gcp.enable_secure_boot, true)
  dp_gcp_integrity    = try(local.dp_gcp.enable_integrity_monitoring, true)
  dp_gcp_sa_email     = trimspace(try(local.dp_gcp.service_account_email, "")) != "" ? local.dp_gcp.service_account_email : null
  dp_gcp_location     = trimspace(try(local.dp_gcp.location, "")) != "" ? local.dp_gcp.location : local.gcp_location
  # Optional zone pinning: node_locations restricts which zones the system pool's nodes land in.
  dp_gcp_node_locations = try(local.dp_gcp.node_locations, [])

  # AWS (EKS) settings — private endpoint by default; public is opt-in and CIDR-scoped
  aws_endpoint_public_access  = try(local.spec.aws.endpoint_public_access, false)
  aws_endpoint_private_access = try(local.spec.aws.endpoint_private_access, true)
  aws_public_access_cidrs     = try(local.spec.aws.public_access_cidrs, ["10.0.0.0/8"])

  aws_auth_mode       = try(local.spec.aws.authentication_mode, "API_AND_CONFIG_MAP")
  aws_bootstrap_admin = try(local.spec.aws.bootstrap_cluster_creator_admin, true)
  aws_enable_irsa     = try(local.spec.aws.enable_irsa, true)
  aws_log_types       = try(local.spec.aws.enabled_log_types, ["api", "audit", "authenticator"])
  aws_tags            = try(local.spec.aws.tags, {})
  # addon toggles (default on)
  aws_addon_vpc_cni   = try(local.spec.aws.addons.vpc_cni, true)
  aws_addon_coredns   = try(local.spec.aws.addons.coredns, true)
  aws_addon_kubeproxy = try(local.spec.aws.addons.kube_proxy, true)
  aws_addon_ebs_csi   = try(local.spec.aws.addons.ebs_csi, true)
  aws_addon_metrics   = try(local.spec.aws.addons.metrics_server, true)

  # GCP (GKE) settings
  gcp_release_channel      = try(local.spec.gcp.release_channel, "STABLE")
  gcp_enable_private_nodes = try(local.spec.gcp.enable_private_nodes, true)

  # region comes from the linked account (never the module spec)
  aws_region  = try(var.inputs.cloud_account.attributes.aws.region, null)
  gcp_region  = try(var.inputs.cloud_account.attributes.gcp.region, null)
  gcp_project = try(var.inputs.cloud_account.attributes.gcp.project_id, null)

  # assume-role details for EKS exec-auth (aws-iam-authenticator --role/-e). Null on GCP.
  aws_role_arn    = try(var.inputs.cloud_account.attributes.aws.role_arn, null)
  aws_external_id = try(var.inputs.cloud_account.attributes.aws.external_id, null)

  # GKE location: a zone (zonal cluster) when gcp.zone is set, else the account region (regional).
  gcp_zone     = trimspace(try(local.spec.gcp.zone, ""))
  gcp_location = local.gcp_zone != "" ? local.gcp_zone : local.gcp_region

  # GKE OIDC issuer — the `iss` claim of GKE-projected SA tokens (emitted in interfaces.gcp so a
  # downstream module can register it as an IAM OIDC provider, e.g. for GKE -> AWS web identity).
  # On an AWS account gcp_project/gcp_location are null. Terraform evaluates BOTH ternary branches
  # eagerly, so the string template must NEVER interpolate a raw null — coalesce() each part to ""
  # inside the template; the outer conditional then still yields null on non-GCP.
  gcp_oidc_issuer = local.is_gcp ? "https://container.googleapis.com/v1/projects/${coalesce(local.gcp_project, "")}/locations/${coalesce(local.gcp_location, "")}/clusters/${coalesce(local.gke_cluster_name, "")}" : null

  gcp_cost_management    = try(local.spec.gcp.cost_management_enabled, false)
  gcp_managed_prometheus = try(local.spec.gcp.managed_prometheus_enabled, false)
  gcp_network_policy     = try(local.spec.gcp.network_policy_enabled, false)
  gcp_logging_enabled    = try(local.spec.gcp.logging_enabled, true)

  # VPC-native (alias IP) secondary ranges from the linked network's interfaces.gcp.
  # When both are present the GKE cluster binds pods/services to those ranges.
  gcp_pods_range          = try(var.inputs.network.interfaces.gcp.gke_pods_range_name, null)
  gcp_services_range      = try(var.inputs.network.interfaces.gcp.gke_services_range_name, null)
  gcp_use_vpc_native      = local.gcp_pods_range != null && local.gcp_services_range != null
  gcp_authorized_networks = try(local.spec.gcp.master_authorized_networks, {})
  gcp_maint_start         = trimspace(try(local.spec.gcp.maintenance_start_time, ""))
  gcp_maint_recurrence    = trimspace(try(local.spec.gcp.maintenance_recurrence, ""))

  # Node Auto Provisioning (NAP) — cluster-level autoscaling that creates/sizes node pools automatically.
  gcp_nap_enabled    = try(local.spec.gcp.nap_enabled, false)
  gcp_nap_min_cpu    = try(local.spec.gcp.nap_min_cpu, 4)
  gcp_nap_max_cpu    = try(local.spec.gcp.nap_max_cpu, 100)
  gcp_nap_min_memory = try(local.spec.gcp.nap_min_memory_gb, 16)
  gcp_nap_max_memory = try(local.spec.gcp.nap_max_memory_gb, 400)

  # network inputs — subnet ids from the linked network resource (defensive reads)
  network_id         = try(var.inputs.network.attributes.network_id, null)
  private_subnet_ids = try(var.inputs.network.attributes.private_subnet_ids, [])
  public_subnet_ids  = try(var.inputs.network.attributes.public_subnet_ids, [])
  # EKS wants private + public subnets; GKE attaches to a single subnetwork
  eks_subnet_ids = concat(local.private_subnet_ids, local.public_subnet_ids)
  gcp_subnetwork = try(local.private_subnet_ids[0], null)

  # per-cloud resolved cluster attributes (only the active branch has a resource)
  aws_cluster_id = try(aws_eks_cluster.this[0].id, null)
  gcp_cluster_id = try(google_container_cluster.this[0].id, null)
  # endpoint must be a full https URL (kube provider host). EKS endpoint already has the scheme;
  # GKE returns a bare IP, so prefix it.
  aws_cluster_endpoint = try(aws_eks_cluster.this[0].endpoint, null)
  gcp_cluster_endpoint = try("https://${google_container_cluster.this[0].endpoint}", null)
  cluster_endpoint     = local.is_aws ? local.aws_cluster_endpoint : local.gcp_cluster_endpoint
  # cluster CA — the kubernetes/helm providers want decoded PEM (both clouds return base64)
  aws_cluster_ca = try(base64decode(aws_eks_cluster.this[0].certificate_authority[0].data), null)
  gcp_cluster_ca = try(base64decode(google_container_cluster.this[0].master_auth[0].cluster_ca_certificate), null)
  # pick the active cloud's CA (no coalesce(); plain conditional keeps null on the inactive side)
  cluster_ca_certificate = local.is_aws ? local.aws_cluster_ca : local.gcp_cluster_ca

  # exec-auth for the kubernetes/helm providers — cloud-neutral {api_version,command,args,env}.
  # The GKE SA key is passed via env (GKE_CREDS), never interpolated into the shell, and written to a
  # 0600 mktemp file (umask 077) cleaned up via trap.
  gke_credentials = try(var.inputs.cloud_account.attributes.gcp.credentials, "")
  kubernetes_provider_exec = local.is_aws ? {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "bash"
    env         = { GKE_CREDS = "" }
    args        = ["-c", "umask 077; command -v aws-iam-authenticator >/dev/null 2>&1 || { T=$(mktemp); curl -sL https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.7.8/aws-iam-authenticator_0.7.8_linux_amd64 -o \"$T\" && chmod +x \"$T\" && mv \"$T\" /usr/local/bin/aws-iam-authenticator; }; aws-iam-authenticator token -i ${local.cluster_name} --role ${coalesce(local.aws_role_arn, "")} -s facets-k8s-${var.instance_name} -e ${coalesce(local.aws_external_id, "")} --region ${coalesce(local.aws_region, "")}"]
    } : {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "bash"
    env         = { GKE_CREDS = local.gke_credentials }
    args        = ["-c", "umask 077; command -v gke-auth-plugin >/dev/null 2>&1 || { T=$(mktemp); curl -sL https://github.com/traviswt/gke-auth-plugin/releases/download/0.3.0/gke-auth-plugin_Linux_x86_64.tar.gz -o \"$T\" && tar -xzf \"$T\" -C /tmp && chmod +x /tmp/gke-auth-plugin && mv /tmp/gke-auth-plugin /usr/local/bin/gke-auth-plugin && rm -f \"$T\"; }; CREDS=$(mktemp); trap 'rm -f \"$CREDS\"' EXIT; printf '%s' \"$GKE_CREDS\" > \"$CREDS\"; GOOGLE_APPLICATION_CREDENTIALS=\"$CREDS\" gke-auth-plugin"]
  }
}

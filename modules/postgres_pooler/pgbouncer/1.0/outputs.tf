# ╔═══════════════════════════════════════════════════════════╗
# ║ Output contract: @facets/postgres  (drop-in)              ║
# ║ Keys managed by CLI — fill in the values only           ║
# ║ Do not add or remove keys. Do not rename.                 ║
# ║                                                           ║
# ║ View schema: raptor get output-type @facets/postgres      ║
# ╚═══════════════════════════════════════════════════════════╝

locals {
  # Pooled endpoints are the plane Services' cluster DNS. Names are deterministic
  # (same substr() rule as the resources), so no index-into-for_each is needed.
  _has_writer = local.pool_writer && local.writer_host != ""
  _writer_svc = substr("${local.base}-writer", 0, 63)
  _reader_svc = substr("${local.base}-reader", 0, 63)
  _ns_suffix  = "${local.namespace}.svc.cluster.local"

  # interfaces.host is ALWAYS the plane Service's cluster DNS — in EVERY expose
  # mode. A type=LoadBalancer Service still keeps its ClusterIP + cluster DNS, so
  # in-cluster consumers resolving this name route ClusterIP→pod via kube-proxy
  # and NEVER traverse the NLB. Only out-of-cluster (ECS/VM) clients use the NLB,
  # via the external_* attributes below. Flipping expose does not repoint any
  # in-cluster consumer.
  # writer → the writer plane Service (fall back to the source writer host only
  # in the degenerate pool_writer=false case, so the contract stays valid).
  writer_pooled_host = local._has_writer ? "${local._writer_svc}.${local._ns_suffix}" : local.writer_host
  # reader → the reader plane Service when it exists, else collapses onto the
  # pooled writer (staging common-pg has no replica → reader == writer).
  reader_pooled_host = local.create_reader ? "${local._reader_svc}.${local._ns_suffix}" : local.writer_pooled_host

  _port_str = tostring(local.listen_port)

  # internal-lb ONLY: the internal NLB DNS fronting each plane, for OUT-OF-CLUSTER
  # (ECS/VM) consumers in the same VPC. Read off the Service status (apply blocks
  # on wait_for_load_balancer, so it is populated). Empty string in clusterip mode
  # — in-cluster consumers ignore these and use interfaces.host (cluster DNS).
  _is_lb          = local.expose == "internal-lb"
  _writer_lb_host = local._is_lb ? try(kubernetes_service_v1.plane["writer"].status[0].load_balancer[0].ingress[0].hostname, "") : ""
  _reader_lb_host = local._is_lb && local.create_reader ? try(kubernetes_service_v1.plane["reader"].status[0].load_balancer[0].ingress[0].hostname, "") : ""

  external_writer_endpoint = local._writer_lb_host != "" ? "${local._writer_lb_host}:${local._port_str}" : ""
  # No distinct reader plane → external reader collapses onto the writer NLB.
  external_reader_endpoint = local._reader_lb_host != "" ? "${local._reader_lb_host}:${local._port_str}" : local.external_writer_endpoint
}

locals {
  # Source attributes passed through verbatim — the RDS behind the pooled
  # endpoint IS the source instance, so its arn/identifier are truthful.
  # external_*_endpoint: the internal NLB host:port for OUT-OF-CLUSTER clients
  # (internal-lb mode only; empty in clusterip mode). In-cluster consumers use
  # interfaces.writer/reader.host (cluster DNS) and never see these.
  output_attributes = {
    arn                      = try(local.spec.source.attributes.arn, "")
    db_instance_identifier   = try(local.spec.source.attributes.db_instance_identifier, "")
    external_writer_endpoint = local.external_writer_endpoint
    external_reader_endpoint = local.external_reader_endpoint
  }

  output_interfaces = {
    writer = {
      host              = local.writer_pooled_host
      port              = local._port_str
      username          = try(local.src_writer.username, "")
      password          = try(local.src_writer.password, "")
      connection_string = "postgres://${local.writer_pooled_host}:${local._port_str}"
      secrets           = ["password"]
    }
    reader = {
      host              = local.reader_pooled_host
      port              = local._port_str
      username          = try(local.src_reader.username, "")
      password          = try(local.src_reader.password, "")
      connection_string = "postgres://${local.reader_pooled_host}:${local._port_str}"
      secrets           = ["password"]
    }
  }
}

# --- END MANAGED SECTION --- Add your custom outputs below ---

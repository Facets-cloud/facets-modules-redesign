# ╔═══════════════════════════════════════════════════════════════════════╗
# ║ postgres_pooler / pgbouncer / 1.0                                       ║
# ║ In-cluster PgBouncer fronting an existing Postgres `source`.            ║
# ║                                                                         ║
# ║ Two planes rendered as independent Deployments+ClusterIP Services:      ║
# ║   <name>-writer  → source.interfaces.writer.host                        ║
# ║   <name>-reader  → source.interfaces.reader.host  (only when distinct)  ║
# ║                                                                         ║
# ║ Auth: STATIC userlist (scram-sha-256) seeded from users.*.credential.   ║
# ║       No auth_query, no pg_shadow, no bootstrap Job.                     ║
# ║ Backend TLS: server_tls_sslmode=require to RDS.                         ║
# ║ Provider: kubernetes (from the kubernetes_details input).               ║
# ║                                                                         ║
# ║ NOTE: read defaulted spec fields with coalesce(spec.x, default) — the   ║
# ║ platform does NOT materialize facets.yaml defaults, and lookup() on the ║
# ║ typed spec object returns null (not the default) for unset optionals.   ║
# ╚═══════════════════════════════════════════════════════════════════════╝

terraform {
  required_version = ">= 1.0"
}

locals {
  spec = var.instance.spec

  # ---- global fallbacks (mirror facets.yaml defaults) ----
  # NOTE: read with lookup(spec, "x", default) — the deploy passes spec as a
  # REDUCED object of only the set fields (defaults are NOT materialized), so a
  # direct local.spec.x on an unset field errors. lookup returns the default
  # when the key is absent.
  pool_mode          = lookup(local.spec, "pool_mode", "transaction")
  default_pool_size  = tonumber(lookup(local.spec, "default_pool_size", 50))
  min_pool_size      = tonumber(lookup(local.spec, "min_pool_size", 10))
  reserve_pool_size  = tonumber(lookup(local.spec, "reserve_pool_size", 5))
  max_db_connections = tonumber(lookup(local.spec, "max_db_connections", 300))
  max_client_conn    = tonumber(lookup(local.spec, "max_client_conn", 3000))
  auth_type          = lookup(local.spec, "auth_type", "scram-sha-256")

  listen_port = tonumber(lookup(local.spec, "listen_port", 5432))
  namespace   = lookup(local.spec, "namespace", "default")
  replicas    = tonumber(lookup(local.spec, "replicas", 2))
  image       = lookup(local.spec, "image", "edoburu/pgbouncer:v1.25.2-p0")
  expose      = lookup(local.spec, "expose", "clusterip")

  # ---- optional node_pool scheduling ----
  # The node_pool input is OPTIONAL: when it is not wired (e.g. AWS, whose
  # general nodes are untainted) these resolve to empty and the pod spec carries
  # no nodeSelector/tolerations — identical to 1.0. When wired (e.g. GCP, where
  # all capacity sits on tainted, dedicated node pools) the pool's node_selector
  # pins the pod to that pool and its taints become tolerations so it can land.
  # The node pool details can arrive nested under .attributes or flattened at the
  # top of the input, depending on how the output is wired — read both, like the
  # service module does.
  node_pool_in    = try(var.inputs.node_pool, {})
  node_pool_attrs = try(local.node_pool_in.attributes, {})
  node_selector   = try(local.node_pool_attrs.node_selector, null) != null ? local.node_pool_attrs.node_selector : try(local.node_pool_in.node_selector, {})
  node_taints     = try(local.node_pool_attrs.taints, null) != null ? local.node_pool_attrs.taints : try(local.node_pool_in.taints, [])
  tolerations = [
    for t in local.node_taints : {
      key      = t.key
      value    = t.value
      operator = "Equal"
      effect   = t.effect
    }
  ]

  # Process-level throughput tuning. Defaults mirror PgBouncer's own, and the
  # lines are rendered only when set away from them (see local.extra_block), so
  # existing consumers keep a byte-identical ini and an unchanged config-hash.
  pkt_buf        = tonumber(lookup(local.spec, "pkt_buf", 4096))
  listen_backlog = tonumber(lookup(local.spec, "listen_backlog", 128))

  # DNS cache TTL for the backend hostname (RDS endpoints can move on failover).
  dns_max_ttl = tonumber(lookup(local.spec, "dns_max_ttl", 15))

  # Pod resources. Defaults are the values previously hardcoded here, so a
  # consumer that sets nothing renders an identical Deployment.
  resources_spec = lookup(local.spec, "resources", {})
  cpu_request    = lookup(local.resources_spec, "cpu_request", "50m")
  cpu_limit      = lookup(local.resources_spec, "cpu_limit", "500m")
  memory_request = lookup(local.resources_spec, "memory_request", "64Mi")
  memory_limit   = lookup(local.resources_spec, "memory_limit", "256Mi")

  # ---- optional metrics pipeline (exporter + otel-collector sidecars) ----
  # OFF by default: when metrics.enabled is false the deployment renders exactly
  # as before (no extra containers, volumes, or configmap). When on, each plane
  # gets a pgbouncer-exporter (scrapes the local admin console) and an
  # otel-collector (scrapes the exporter, pushes OTLP to metrics.otlp_endpoint).
  metrics_spec    = lookup(local.spec, "metrics", {})
  metrics_enabled = tobool(lookup(local.metrics_spec, "enabled", false))
  metrics_otlp    = lookup(local.metrics_spec, "otlp_endpoint", "")
  exporter_image  = lookup(local.metrics_spec, "exporter_image", "prometheuscommunity/pgbouncer-exporter:v0.10.2")
  collector_image = lookup(local.metrics_spec, "collector_image", "otel/opentelemetry-collector-contrib:0.159.0")
  exporter_port   = tonumber(lookup(local.metrics_spec, "exporter_port", 9127))
  scrape_interval = lookup(local.metrics_spec, "scrape_interval", "30s")
  # DSN the exporter uses to read the pgbouncer admin console (same pod, plaintext
  # loopback). Kept in the plane Secret, referenced by secretKeyRef — never inline.
  exporter_dsn = "postgres://${local.admin_user}:${random_password.admin.result}@127.0.0.1:${local.listen_port}/pgbouncer?sslmode=disable"

  # Collector config is env-templated (${env:VAR}) so ONE configmap serves every
  # plane; the per-plane service.name is injected via the SERVICE_NAME env below.
  otel_collector_yaml = <<-EOT
    receivers:
      prometheus:
        config:
          scrape_configs:
            - job_name: pgbouncer
              scrape_interval: $${env:SCRAPE_INTERVAL}
              static_configs:
                - targets: ["127.0.0.1:$${env:EXPORTER_PORT}"]
    processors:
      resource:
        attributes:
          - {key: service.name, value: "$${env:SERVICE_NAME}", action: upsert}
          - {key: deployment.environment, value: "$${env:DEPLOY_ENV}", action: upsert}
      batch: {}
    exporters:
      otlp:
        endpoint: "$${env:OTLP_ENDPOINT}"
        tls:
          insecure: true
    service:
      telemetry:
        metrics:
          level: none
      pipelines:
        metrics:
          receivers: [prometheus]
          processors: [resource, batch]
          exporters: [otlp]
  EOT

  # Health probes. Same rule: defaults reproduce the previous hardcoded probes.
  health_checks  = lookup(local.spec, "health_checks", {})
  liveness       = lookup(local.health_checks, "liveness", {})
  readiness      = lookup(local.health_checks, "readiness", {})
  live_delay     = tonumber(lookup(local.liveness, "initial_delay_seconds", 15))
  live_period    = tonumber(lookup(local.liveness, "period_seconds", 20))
  live_timeout   = tonumber(lookup(local.liveness, "timeout_seconds", 1))
  live_failures  = tonumber(lookup(local.liveness, "failure_threshold", 3))
  ready_delay    = tonumber(lookup(local.readiness, "initial_delay_seconds", 5))
  ready_period   = tonumber(lookup(local.readiness, "period_seconds", 10))
  ready_timeout  = tonumber(lookup(local.readiness, "timeout_seconds", 1))
  ready_failures = tonumber(lookup(local.readiness, "failure_threshold", 3))

  pool_writer = tobool(lookup(local.spec, "pool_writer", true))
  pool_reader = tobool(lookup(local.spec, "pool_reader", true))

  # ---- source (@facets/postgres full outputs; required, always set) ----
  src_writer = try(local.spec.source.interfaces.writer, {})
  src_reader = try(local.spec.source.interfaces.reader, {})

  writer_host = try(local.src_writer.host, "")
  writer_port = tostring(try(local.src_writer.port, "5432"))
  reader_host = try(local.src_reader.host, "")
  reader_port = tostring(try(local.src_reader.port, "5432"))

  # Reader plane exists only when pooling the reader is asked for AND the source
  # exposes a reader endpoint genuinely distinct from the writer. On a
  # replica-less instance (e.g. staging common-pg) reader.host == writer.host,
  # so the reader plane is skipped and interfaces.reader collapses onto writer.
  create_reader = local.pool_reader && local.reader_host != "" && local.reader_host != local.writer_host

  # ---- per-plane free-form overrides (omitted keys inherit the globals) ----
  writer_overrides = lookup(local.spec, "writer", {})
  reader_overrides = lookup(local.spec, "reader", {})

  # Effective (override-merged) config per plane, keyed by plane name.
  planes = merge(
    local.pool_writer ? {
      writer = {
        host               = local.writer_host
        port               = local.writer_port
        pool_mode          = try(local.writer_overrides.pool_mode, local.pool_mode)
        default_pool_size  = try(local.writer_overrides.default_pool_size, local.default_pool_size)
        min_pool_size      = try(local.writer_overrides.min_pool_size, local.min_pool_size)
        reserve_pool_size  = try(local.writer_overrides.reserve_pool_size, local.reserve_pool_size)
        max_db_connections = try(local.writer_overrides.max_db_connections, local.max_db_connections)
      }
    } : {},
    local.create_reader ? {
      reader = {
        host               = local.reader_host
        port               = local.reader_port
        pool_mode          = try(local.reader_overrides.pool_mode, local.pool_mode)
        default_pool_size  = try(local.reader_overrides.default_pool_size, local.default_pool_size)
        min_pool_size      = try(local.reader_overrides.min_pool_size, local.min_pool_size)
        reserve_pool_size  = try(local.reader_overrides.reserve_pool_size, local.reserve_pool_size)
        max_db_connections = try(local.reader_overrides.max_db_connections, local.max_db_connections)
      }
    } : {},
  )

  # ---- users / static userlist ----
  users      = lookup(local.spec, "users", {})
  admin_user = "pgbouncer_admin"

  # userlist.txt: one line per app user (plaintext pw so pgbouncer can negotiate
  # scram with both the client and the backend), plus a generated admin for
  # SHOW POOLS / SHOW STATS on the admin console.
  userlist_txt = join("\n", concat(
    [for u, cfg in local.users : format("\"%s\" \"%s\"", u, lookup(cfg, "credential", ""))],
    [format("\"%s\" \"%s\"", local.admin_user, random_password.admin.result)],
  ))

  # [users] section: per-user throttle / pool_mode overrides. Users with no
  # override inherit the [pgbouncer] globals and get no line here.
  users_section = join("\n", [
    for u, cfg in local.users : format("%s = %s", u, trimspace(join(" ", compact([
      lookup(cfg, "max_user_connections", null) != null ? "max_user_connections=${cfg.max_user_connections}" : "",
      lookup(cfg, "pool_mode", null) != null ? "pool_mode=${cfg.pool_mode}" : "",
    ]))))
    if lookup(cfg, "max_user_connections", null) != null || lookup(cfg, "pool_mode", null) != null
  ])

  # ---- client-side TLS ----
  client_tls       = lookup(local.spec, "client_tls", {})
  client_tls_mode  = lookup(local.client_tls, "sslmode", "allow")
  client_tls_cert  = lookup(local.client_tls, "cert", "")
  client_tls_on    = local.client_tls_mode != "disable" && local.client_tls_cert != ""
  client_cert_path = "/etc/pgbouncer/client-tls.pem"
  client_tls_block = local.client_tls_on ? join("\n", [
    "client_tls_sslmode = ${local.client_tls_mode}",
    "client_tls_cert_file = ${local.client_cert_path}",
    "client_tls_key_file = ${local.client_cert_path}",
  ]) : ""

  # Optional [pgbouncer] lines, emitted only when non-default. compact() drops
  # the empties, so with nothing set this renders exactly as client_tls_block
  # did before — no ini churn for existing poolers.
  extra_block = join("\n", compact([
    local.pkt_buf != 4096 ? "pkt_buf = ${local.pkt_buf}" : "",
    local.listen_backlog != 128 ? "listen_backlog = ${local.listen_backlog}" : "",
    local.client_tls_block,
  ]))

  # ---- pgbouncer.ini per plane ----
  # Wildcard [databases]: the @facets/postgres contract carries no dbname, so we
  # forward the client's requested database verbatim to the backend (real dbname,
  # no _ro alias). Planes differ only by backend host → pure host-routing.
  pgbouncer_ini = { for pname, p in local.planes : pname => <<-EOT
    [databases]
    * = host=${p.host} port=${p.port}

    [pgbouncer]
    listen_addr = 0.0.0.0
    listen_port = ${local.listen_port}
    auth_type = ${local.auth_type}
    auth_file = /etc/pgbouncer/userlist.txt
    pool_mode = ${p.pool_mode}
    default_pool_size = ${p.default_pool_size}
    min_pool_size = ${p.min_pool_size}
    reserve_pool_size = ${p.reserve_pool_size}
    max_db_connections = ${p.max_db_connections}
    max_client_conn = ${local.max_client_conn}
    server_tls_sslmode = require
    dns_max_ttl = ${local.dns_max_ttl}
    ignore_startup_parameters = extra_float_digits,options
    admin_users = ${local.admin_user}
    stats_users = ${local.admin_user}
    ${local.extra_block}
    [users]
    ${local.users_section}
  EOT
  }

  # ---- naming / labels ----
  base = var.instance_name
  labels = {
    "app.kubernetes.io/name"       = "pgbouncer"
    "app.kubernetes.io/instance"   = var.instance_name
    "app.kubernetes.io/component"  = "connection-pooler"
    "app.kubernetes.io/managed-by" = "facets"
  }
}

# Admin credential for the pgbouncer admin console (SHOW POOLS / SHOW STATS).
resource "random_password" "admin" {
  length  = 24
  special = false
}

# ─────────────────────────────────────────────────────────────
# Preconditions — fail fast with a clear message on bad wiring.
# ─────────────────────────────────────────────────────────────
resource "terraform_data" "preconditions" {
  input = local.base
  lifecycle {
    precondition {
      condition     = local.writer_host != ""
      error_message = "postgres_pooler/pgbouncer: spec.source (@facets/postgres) did not resolve a writer host. Wire `source` to a postgres resource."
    }
    precondition {
      condition     = length(local.users) > 0
      error_message = "postgres_pooler/pgbouncer: spec.users is empty. Declare at least one user with a credential (secret-ref) so the static userlist can authenticate clients."
    }
    precondition {
      condition     = local.client_tls_mode != "require" || local.client_tls_cert != ""
      error_message = "postgres_pooler/pgbouncer: client_tls.sslmode=require needs client_tls.cert (a secret-ref to the server cert+key PEM)."
    }
  }
}

# ─────────────────────────────────────────────────────────────
# Per-plane Secret (pgbouncer.ini + userlist.txt [+ client cert]),
# Deployment, Service and PodDisruptionBudget.
# ─────────────────────────────────────────────────────────────
resource "kubernetes_secret_v1" "plane" {
  for_each = local.planes
  metadata {
    name      = substr("${local.base}-${each.key}", 0, 63)
    namespace = local.namespace
    labels    = merge(local.labels, { "app.kubernetes.io/plane" = each.key })
  }
  data = merge(
    {
      "pgbouncer.ini" = local.pgbouncer_ini[each.key]
      "userlist.txt"  = local.userlist_txt
    },
    local.client_tls_on ? { "client-tls.pem" = local.client_tls_cert } : {},
    local.metrics_enabled ? { "exporter_dsn" = local.exporter_dsn } : {},
  )
  depends_on = [terraform_data.preconditions]
}

# OTEL collector config (one ConfigMap, env-templated for all planes). Only when metrics on.
resource "kubernetes_config_map_v1" "metrics" {
  count = local.metrics_enabled ? 1 : 0
  metadata {
    name      = substr("${local.base}-otelcol", 0, 63)
    namespace = local.namespace
    labels    = local.labels
  }
  data = { "config.yaml" = local.otel_collector_yaml }
}

resource "kubernetes_deployment_v1" "plane" {
  for_each = local.planes
  metadata {
    name      = substr("${local.base}-${each.key}", 0, 63)
    namespace = local.namespace
    labels    = merge(local.labels, { "app.kubernetes.io/plane" = each.key })
  }
  spec {
    replicas = local.replicas
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "pgbouncer"
        "app.kubernetes.io/instance" = var.instance_name
        "app.kubernetes.io/plane"    = each.key
      }
    }
    template {
      metadata {
        labels = merge(local.labels, { "app.kubernetes.io/plane" = each.key })
        annotations = {
          "facets.cloud/config-hash" = substr(sha256("${local.pgbouncer_ini[each.key]}${local.userlist_txt}"), 0, 16)
        }
      }
      spec {
        node_selector = local.node_selector
        dynamic "toleration" {
          for_each = local.tolerations
          content {
            key      = toleration.value.key
            value    = toleration.value.value
            operator = toleration.value.operator
            effect   = toleration.value.effect
          }
        }
        container {
          name  = "pgbouncer"
          image = local.image
          port {
            name           = "postgres"
            container_port = local.listen_port
          }
          volume_mount {
            name       = "config"
            mount_path = "/etc/pgbouncer"
            read_only  = true
          }
          liveness_probe {
            tcp_socket { port = local.listen_port }
            initial_delay_seconds = local.live_delay
            period_seconds        = local.live_period
            timeout_seconds       = local.live_timeout
            failure_threshold     = local.live_failures
          }
          readiness_probe {
            tcp_socket { port = local.listen_port }
            initial_delay_seconds = local.ready_delay
            period_seconds        = local.ready_period
            timeout_seconds       = local.ready_timeout
            failure_threshold     = local.ready_failures
          }
          resources {
            requests = { cpu = local.cpu_request, memory = local.memory_request }
            limits   = { cpu = local.cpu_limit, memory = local.memory_limit }
          }
        }

        # pgbouncer-exporter + otel-collector run as plain sidecar containers.
        # NOTE: native sidecars (init_container + restart_policy=Always) would be
        # the ideal decoupling, but the platform's kubernetes provider predates
        # that field (< v2.35) and rejects it — so these are regular containers.
        # They carry NO readiness probe, so while Running they do not gate the
        # pod's Ready condition; the risk is a crash-loop (a bad image/config),
        # which is why the collector image is pinned to a known-good tag. Keep
        # them last so a metrics change never reorders the pgbouncer container.

        # pgbouncer-exporter: reads the admin console, exposes Prometheus metrics.
        dynamic "container" {
          for_each = local.metrics_enabled ? [1] : []
          content {
            name  = "pgbouncer-exporter"
            image = local.exporter_image
            args  = ["--pgBouncer.connectionString=$(PGBOUNCER_DSN)", "--web.listen-address=:${local.exporter_port}"]
            env {
              name = "PGBOUNCER_DSN"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret_v1.plane[each.key].metadata[0].name
                  key  = "exporter_dsn"
                }
              }
            }
            port {
              name           = "metrics"
              container_port = local.exporter_port
            }
            resources {
              requests = { cpu = "10m", memory = "24Mi" }
              limits   = { cpu = "100m", memory = "64Mi" }
            }
          }
        }

        # otel-collector: scrapes the exporter and pushes OTLP to the collector.
        dynamic "container" {
          for_each = local.metrics_enabled ? [1] : []
          content {
            name  = "otel-collector"
            image = local.collector_image
            args  = ["--config=/etc/otelcol/config.yaml"]
            env {
              name  = "SERVICE_NAME"
              value = "${var.instance_name}-${each.key}-pooler"
            }
            env {
              name  = "DEPLOY_ENV"
              value = var.environment.name
            }
            env {
              name  = "OTLP_ENDPOINT"
              value = local.metrics_otlp
            }
            env {
              name  = "EXPORTER_PORT"
              value = tostring(local.exporter_port)
            }
            env {
              name  = "SCRAPE_INTERVAL"
              value = local.scrape_interval
            }
            volume_mount {
              name       = "otelcol-config"
              mount_path = "/etc/otelcol"
              read_only  = true
            }
            resources {
              requests = { cpu = "20m", memory = "48Mi" }
              limits   = { cpu = "150m", memory = "128Mi" }
            }
          }
        }

        volume {
          name = "config"
          secret {
            secret_name = kubernetes_secret_v1.plane[each.key].metadata[0].name
          }
        }
        dynamic "volume" {
          for_each = local.metrics_enabled ? [1] : []
          content {
            name = "otelcol-config"
            config_map {
              name = kubernetes_config_map_v1.metrics[0].metadata[0].name
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "plane" {
  for_each = local.planes
  # internal-lb: block the apply until the NLB has an ingress address, so
  # outputs.tf can read the NLB DNS off status. No-op for ClusterIP.
  wait_for_load_balancer = local.expose == "internal-lb"
  metadata {
    name      = substr("${local.base}-${each.key}", 0, 63)
    namespace = local.namespace
    labels    = merge(local.labels, { "app.kubernetes.io/plane" = each.key })
    # internal-lb: one internal NLB per plane, provisioned by the AWS Load
    # Balancer Controller in EXTERNAL mode with ip targets (direct pod-IP
    # routing, client IP preserved). Subnets auto-discovered via the
    # kubernetes.io/role/internal-elb tag; cross-zone on for even spread.
    annotations = local.expose == "internal-lb" ? {
      "service.beta.kubernetes.io/aws-load-balancer-scheme"               = "internal"
      "service.beta.kubernetes.io/aws-load-balancer-type"                 = "external"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"      = "ip"
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol" = "TCP"
      "service.beta.kubernetes.io/aws-load-balancer-attributes"           = "load_balancing.cross_zone.enabled=true"
    } : {}
  }
  spec {
    selector = {
      "app.kubernetes.io/name"     = "pgbouncer"
      "app.kubernetes.io/instance" = var.instance_name
      "app.kubernetes.io/plane"    = each.key
    }
    port {
      name        = "postgres"
      port        = local.listen_port
      target_port = local.listen_port
    }
    type = local.expose == "internal-lb" ? "LoadBalancer" : "ClusterIP"
  }
}

resource "kubernetes_pod_disruption_budget_v1" "plane" {
  for_each = { for k, v in local.planes : k => v if local.replicas > 1 }
  metadata {
    name      = substr("${local.base}-${each.key}", 0, 63)
    namespace = local.namespace
    labels    = merge(local.labels, { "app.kubernetes.io/plane" = each.key })
  }
  spec {
    min_available = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "pgbouncer"
        "app.kubernetes.io/instance" = var.instance_name
        "app.kubernetes.io/plane"    = each.key
      }
    }
  }
}

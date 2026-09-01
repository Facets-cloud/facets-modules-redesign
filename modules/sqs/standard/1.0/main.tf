data "aws_region" "current" {}

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 75
  resource_name = var.instance_name
  resource_type = "sqs"
}

locals {
  spec = var.instance.spec

  queue_config = lookup(local.spec, "queue_config", {})
  is_fifo      = lookup(local.queue_config, "fifo_queue", false)

  # spec.name carries the LIVE queue name. `name` is ForceNew on aws_sqs_queue, so emitting a
  # different one plans destroy+create — message loss on a production queue. An explicit spec.name
  # must always win, and it is used VERBATIM: a live FIFO queue's name already ends in `.fifo`, so
  # nothing may be appended to it.
  # Identity lives in spec.imports, which is overrides-only: production pins the live object
  # there, a new environment has no override and builds its own. spec.name is still honoured as a
  # fallback so publishing this schema cannot orphan a resource whose override has not migrated —
  # the name is ForceNew, and losing it emits a generated one and plans destroy+create.
  imports     = lookup(local.spec, "imports", {})
  adopt       = lookup(local.imports, "import_existing", false)
  import_name = lookup(local.imports, "queue_name", null)
  legacy_name = lookup(local.spec, "name", null)
  name_override = (local.import_name != null && local.import_name != "" ? local.import_name
  : (local.legacy_name != null && local.legacy_name != "" ? local.legacy_name : null))
  # LOCAL/regional resource -> short ${instance}-${env.name} (naming convention).
  name_prefix    = "${var.instance_name}-${var.environment.name}"
  generated_name = local.is_fifo ? "${local.name_prefix}.fifo" : local.name_prefix
  queue_name = (local.name_override == null || local.name_override == ""
    ? local.generated_name
  : local.name_override)

  visibility_timeout_seconds  = lookup(local.queue_config, "visibility_timeout_seconds", 30)
  message_retention_seconds   = lookup(local.queue_config, "message_retention_seconds", 345600)
  max_message_size            = lookup(local.queue_config, "max_message_size", 262144)
  delay_seconds               = lookup(local.queue_config, "delay_seconds", 0)
  receive_wait_time_seconds   = lookup(local.queue_config, "receive_wait_time_seconds", 0)
  content_based_deduplication = lookup(local.queue_config, "content_based_deduplication", false)

  # FIFO-only knobs. Present on all 8 live FIFO queues and unmodelled before 1.1, so they read as a
  # config change on adoption. Emitted as null on a standard queue — the provider rejects them there.
  deduplication_scope   = lookup(local.queue_config, "deduplication_scope", null)
  fifo_throughput_limit = lookup(local.queue_config, "fifo_throughput_limit", null)

  # ── Encryption ────────────────────────────────────────────────────────────────────────────────
  # TWO DIFFERENT THINGS, and 1.0 could only express one of them:
  #   SSE-SQS  -> sqs_managed_sse_enabled = true        (all 167 live queues in this estate)
  #   SSE-KMS  -> kms_master_key_id = <key or alias>    (0 live queues)
  # They are mutually exclusive in the API. 1.0 set kms_master_key_id = "alias/aws/sqs" whenever
  # encryption was on, which is SSE-KMS — on an SSE-SQS queue that is a real in-place change.
  encryption_config = lookup(local.spec, "encryption_config", {})
  kms_key_id        = lookup(local.encryption_config, "kms_key_id", null)
  sqs_managed_sse   = lookup(local.encryption_config, "sqs_managed_sse_enabled", true)

  # A KMS key wins if one is given; otherwise SSE-SQS. Never both.
  use_kms                           = local.kms_key_id != null && local.kms_key_id != ""
  kms_master_key_id                 = local.use_kms ? local.kms_key_id : null
  sqs_managed_sse_enabled           = local.use_kms ? null : local.sqs_managed_sse
  kms_data_key_reuse_period_seconds = local.use_kms ? lookup(local.encryption_config, "kms_data_key_reuse_period_seconds", 300) : null

  # ── Redrive ───────────────────────────────────────────────────────────────────────────────────
  # A dead-letter queue is ANOTHER queue, not a child of this one. 34 of the 167 live queues are
  # themselves the DLQ target of a sibling, so modelling the DLQ as a child resource (as 1.0 did)
  # would either double-manage those 34 or create duplicates alongside them. Instead the redrive
  # target is a reference: ${sqs.<dlq>.out.attributes.queue_arn}.
  redrive               = lookup(local.spec, "redrive", {})
  dead_letter_queue_arn = lookup(local.redrive, "dead_letter_queue_arn", null)
  max_receive_count     = lookup(local.redrive, "max_receive_count", 3)
  has_redrive           = local.dead_letter_queue_arn != null && local.dead_letter_queue_arn != ""

  # ── Access policy ─────────────────────────────────────────────────────────────────────────────
  # 29 live queues carry a resource policy; 1.0 did not model aws_sqs_queue_policy at all, so those
  # policies would have been left dangling outside management. __QUEUE_ARN__ is substituted here
  # rather than referenced through Facets: a resource cannot reference its own output (that is a
  # cycle the validator rejects), but aws_sqs_queue_policy is a SEPARATE resource, so reading
  # aws_sqs_queue.main.arn from it is legitimate.
  raw_policy = lookup(local.spec, "queue_policy_json", null)
  queue_policy_json = (local.raw_policy == null || local.raw_policy == ""
    ? ""
    : replace(local.raw_policy, "__QUEUE_ARN__", aws_sqs_queue.main.arn)
  )
  # count must be known at plan; the substituted policy references the queue ARN
  # (unknown for a NEW queue), so gate on the raw INPUT, which is always known.
  has_queue_policy = local.raw_policy != null && local.raw_policy != ""

  # ── Tags ──────────────────────────────────────────────────────────────────────────────────────
  # On a greenfield queue the environment's cloud_tags plus the Facets identity tags are wanted. On
  # an ADOPTED queue they are an in-place `~ tags` change to someone else's resource — and 82 of the
  # 167 live queues carry no tags at all, while only 12 have a Name tag. inject_env_tags=false makes
  # spec.tags the complete, authoritative set, so `tags = {}` faithfully means "live has none".
  custom_tags     = lookup(local.spec, "tags", {})
  inject_env_tags = lookup(local.spec, "inject_env_tags", true)

  facets_tags = {
    Name          = var.instance_name
    resource_type = "sqs"
    flavor        = "standard"
  }

  all_tags = local.inject_env_tags ? merge(
    var.environment.cloud_tags,
    local.custom_tags,
    local.facets_tags,
  ) : local.custom_tags

  # Off by default: two IAM policies per queue across an adopted estate is 334 brand-new IAM
  # policies, which is a real create on every plan.
  create_iam_policies = lookup(local.spec, "create_iam_policies", false)
}

resource "aws_sqs_queue" "main" {
  name = local.queue_name

  fifo_queue                  = local.is_fifo
  content_based_deduplication = local.is_fifo ? local.content_based_deduplication : null
  deduplication_scope         = local.is_fifo ? local.deduplication_scope : null
  fifo_throughput_limit       = local.is_fifo ? local.fifo_throughput_limit : null

  visibility_timeout_seconds = local.visibility_timeout_seconds
  message_retention_seconds  = local.message_retention_seconds
  max_message_size           = local.max_message_size
  delay_seconds              = local.delay_seconds
  receive_wait_time_seconds  = local.receive_wait_time_seconds

  sqs_managed_sse_enabled           = local.sqs_managed_sse_enabled
  kms_master_key_id                 = local.kms_master_key_id
  kms_data_key_reuse_period_seconds = local.kms_data_key_reuse_period_seconds

  redrive_policy = local.has_redrive ? jsonencode({
    deadLetterTargetArn = local.dead_letter_queue_arn
    maxReceiveCount     = local.max_receive_count
  }) : null

  tags = local.all_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_sqs_queue_policy" "main" {
  count = local.has_queue_policy ? 1 : 0

  queue_url = aws_sqs_queue.main.url
  policy    = local.queue_policy_json
}

resource "aws_iam_policy" "producer" {
  count = local.create_iam_policies ? 1 : 0

  name        = "${module.name.name}-sqs-producer"
  description = "Send messages to ${local.queue_name} SQS queue"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.main.arn
      }
      ],
      local.use_kms ? [{
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = local.kms_key_id
      }] : []
    )
  })
  tags = local.all_tags
}

resource "aws_iam_policy" "consumer" {
  count = local.create_iam_policies ? 1 : 0

  name        = "${module.name.name}-sqs-consumer"
  description = "Receive messages from ${local.queue_name} SQS queue"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueUrl",
        "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
        Resource = aws_sqs_queue.main.arn
      }
      ],
      local.use_kms ? [{
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = local.kms_key_id
      }] : []
    )
  })
  tags = local.all_tags
}

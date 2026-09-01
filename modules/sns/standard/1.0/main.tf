# SNS — adoption-capable rework of 1.0.
#
# 1.0 declared spec.import_existing + spec.imports.* and wired NONE of it (zero `import` references
# in any .tf), carried the root-level `imports:` landmine, created its own SQS queue as a delivery
# DLQ, and modelled neither the topic policy nor subscriptions — while all 80 live topics have a
# policy and 64 of them have subscribers.

data "aws_region" "current" {}

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 251
  resource_name = var.instance_name
  resource_type = "sns"
}

locals {
  spec = var.instance.spec

  is_fifo = lookup(local.spec, "fifo_topic", false)

  # spec.name carries the LIVE topic name, verbatim. `name` is ForceNew on aws_sns_topic, so a
  # generated one on an adopted topic plans destroy+create — and every subscription goes with it.
  # Identity lives in spec.imports, which is overrides-only: production pins the live object
  # there, a new environment has no override and builds its own. spec.name is still honoured as a
  # fallback so publishing this schema cannot orphan a resource whose override has not migrated —
  # the name is ForceNew, and losing it emits a generated one and plans destroy+create.
  imports     = lookup(local.spec, "imports", {})
  adopt       = lookup(local.imports, "import_existing", false)
  import_name = lookup(local.imports, "topic_name", null)
  legacy_name = lookup(local.spec, "name", null)
  name_override = (local.import_name != null && local.import_name != "" ? local.import_name
  : (local.legacy_name != null && local.legacy_name != "" ? local.legacy_name : null))
  # LOCAL/regional resource -> short ${instance}-${env.name} (naming convention).
  name_prefix    = "${var.instance_name}-${var.environment.name}"
  generated_name = local.is_fifo ? "${local.name_prefix}.fifo" : local.name_prefix
  topic_name = (local.name_override == null || local.name_override == ""
    ? local.generated_name
  : local.name_override)

  # 60 of 80 live topics have NO display name. 1.0 defaulted it to the instance name, which sets one
  # on all 60 — a real change. Absent means absent.
  display_name = lookup(local.spec, "display_name", null)

  # 75 topics use alias/aws/sns, 5 use NOTHING. 1.0 forced alias/aws/sns whenever encryption was on
  # (default true), which switches encryption ON for those 5. Absent means unencrypted.
  kms_master_key_id = lookup(local.spec, "kms_master_key_id", null)

  # PassThrough on 10 topics; the provider default is also PassThrough, but stating it keeps the
  # blueprint honest about what is managed rather than relying on a default.
  tracing_config = lookup(local.spec, "tracing_config", null)

  # Delivery-status logging: 3 topics carry up to 11 of these. Unmodelled they are stripped, which
  # silently switches off delivery logging on the busiest topics in the estate.
  dsl = lookup(local.spec, "delivery_status_logging", {})

  # All 80 live topics have a resource policy; 1.0 modelled none. __TOPIC_ARN__ is substituted here
  # because a resource cannot reference its own output (a cycle the validator rejects) — but
  # aws_sns_topic_policy is a SEPARATE resource, so reading aws_sns_topic.main.arn is legitimate.
  raw_policy = lookup(local.spec, "topic_policy_json", null)
  topic_policy_json = (local.raw_policy == null || local.raw_policy == ""
    ? ""
    : replace(local.raw_policy, "__TOPIC_ARN__", aws_sns_topic.main.arn)
  )
  # count must be known at plan; the substituted policy references the topic ARN
  # (unknown for a NEW topic), so gate on the raw INPUT, which is always known.
  has_policy = local.raw_policy != null && local.raw_policy != ""

  subscriptions = lookup(local.spec, "subscriptions", {})

  custom_tags     = lookup(local.spec, "tags", {})
  inject_env_tags = lookup(local.spec, "inject_env_tags", true)
  facets_tags     = { Name = var.instance_name, resource_type = "sns", flavor = "standard" }
  all_tags = local.inject_env_tags ? merge(
    var.environment.cloud_tags, local.custom_tags, local.facets_tags,
  ) : local.custom_tags

  # Off by default: two IAM policies per topic across 80 topics is 160 brand-new IAM policies.
  create_iam_policies = lookup(local.spec, "create_iam_policies", false)
}

resource "aws_sns_topic" "main" {
  name         = local.topic_name
  display_name = local.display_name

  fifo_topic                  = local.is_fifo
  content_based_deduplication = local.is_fifo ? lookup(local.spec, "content_based_deduplication", false) : null

  kms_master_key_id = local.kms_master_key_id
  tracing_config    = local.tracing_config

  application_success_feedback_sample_rate = lookup(local.dsl, "application_success_feedback_sample_rate", null)
  firehose_success_feedback_role_arn       = lookup(local.dsl, "firehose_success_feedback_role_arn", null)
  firehose_success_feedback_sample_rate    = lookup(local.dsl, "firehose_success_feedback_sample_rate", null)
  firehose_failure_feedback_role_arn       = lookup(local.dsl, "firehose_failure_feedback_role_arn", null)
  http_success_feedback_role_arn           = lookup(local.dsl, "http_success_feedback_role_arn", null)
  http_success_feedback_sample_rate        = lookup(local.dsl, "http_success_feedback_sample_rate", null)
  http_failure_feedback_role_arn           = lookup(local.dsl, "http_failure_feedback_role_arn", null)
  lambda_success_feedback_role_arn         = lookup(local.dsl, "lambda_success_feedback_role_arn", null)
  lambda_success_feedback_sample_rate      = lookup(local.dsl, "lambda_success_feedback_sample_rate", null)
  lambda_failure_feedback_role_arn         = lookup(local.dsl, "lambda_failure_feedback_role_arn", null)
  sqs_success_feedback_role_arn            = lookup(local.dsl, "sqs_success_feedback_role_arn", null)
  sqs_success_feedback_sample_rate         = lookup(local.dsl, "sqs_success_feedback_sample_rate", null)
  sqs_failure_feedback_role_arn            = lookup(local.dsl, "sqs_failure_feedback_role_arn", null)

  tags = local.all_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_sns_topic_policy" "main" {
  count = local.has_policy ? 1 : 0

  arn    = aws_sns_topic.main.arn
  policy = local.topic_policy_json
}

# 73 live subscriptions across 64 topics — 1.0 modelled none, so importing topics alone leaves every
# subscriber outside management and a new environment comes up with nothing wired to the topic.
resource "aws_sns_topic_subscription" "main" {
  for_each = local.subscriptions

  topic_arn = aws_sns_topic.main.arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint

  raw_message_delivery  = lookup(each.value, "raw_message_delivery", false)
  filter_policy         = lookup(each.value, "filter_policy", null)
  filter_policy_scope   = lookup(each.value, "filter_policy_scope", null)
  redrive_policy        = lookup(each.value, "redrive_policy", null)
  subscription_role_arn = lookup(each.value, "subscription_role_arn", null)

  # An email subscription is only live once a human clicks the confirmation link; terraform cannot
  # do that, and it cannot read the endpoint back for a confirmed one either.
  endpoint_auto_confirms = lookup(each.value, "endpoint_auto_confirms", false)

  lifecycle {
    ignore_changes = [
      # For a CONFIRMED email subscription AWS returns the endpoint obfuscated, so terraform would
      # compare "what I want" against a masked value and show a perpetual diff. Not a staging
      # blocker: a NEW subscription sets the endpoint at create.
      endpoint,

      # TERRAFORM-ONLY, no AWS footprint. Both govern how terraform CREATES a subscription — how
      # long to wait for confirmation, and whether the endpoint self-confirms. AWS never returns
      # them, so an imported subscription has null in state while the provider schema defaults them
      # to 1 and false, giving `+ confirmation_timeout_in_minutes` / `+ endpoint_auto_confirms` on
      # every adopted subscription (all 73 in this estate). Ignoring them changes nothing in the
      # cloud and nothing on create, which is why this is a provider-echo case rather than hiding a
      # real diff — the same shape as SQS's skip_final_snapshot.
      confirmation_timeout_in_minutes,
      endpoint_auto_confirms,
    ]
  }
}

resource "aws_iam_policy" "publisher" {
  count = local.create_iam_policies ? 1 : 0

  name        = "${module.name.name}-sns-publisher"
  description = "Publish to ${local.topic_name}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish", "sns:GetTopicAttributes"]
      Resource = aws_sns_topic.main.arn
    }]
  })
  tags = local.all_tags
}

locals {
  unique_domain           = var.instance.spec.domain
  wildcard_domain         = "*.${local.unique_domain}"
  subnets                 = var.instance.spec.public ? var.inputs.network_details.attributes.public_subnet_ids : var.inputs.network_details.attributes.private_subnet_ids
  forward_ecs_rules       = { for rule_key, rule in var.instance.spec.rules : rule_key => rule if lookup(rule, "action_type", "forward-ecs") == "forward-ecs" }
  oidc_auth_map           = { for auth in lookup(var.instance.spec, "oidc_authentications", {}) : auth.name => auth }
  additional_certificates = distinct([for domain_key, domain in lookup(var.instance.spec, "additional_domains", {}) : domain.certificate_arn])
}

resource "aws_lb_listener_certificate" "additional_certs" {
  provider        = aws
  for_each        = toset(local.additional_certificates)
  listener_arn    = aws_lb_listener.https.arn
  certificate_arn = each.value
}

resource "aws_lambda_invocation" "ecs_target_group_invocation" {
  provider = aws
  for_each = { for rule_key, rule in local.forward_ecs_rules : rule_key => rule }
  triggers = {
    input = jsonencode({
      target_group_arn = aws_lb_target_group.ecs_target_group[each.key].arn
      ecs_service_arn  = each.value.ecs_service_arn
      port             = each.value.port
      container_name   = lookup(each.value, "container_name", "")
    })
  }
  function_name = aws_lambda_function.ecs_rule_manager.function_name
  input = jsonencode({
    target_group_arn = aws_lb_target_group.ecs_target_group[each.key].arn
    ecs_service_arn  = each.value.ecs_service_arn
    port             = each.value.port
    container_name   = lookup(each.value, "container_name", "")
  })
  lifecycle_scope = "CRUD"
  depends_on = [
    aws_lambda_function.ecs_rule_manager,
    aws_lb_listener_rule.https_forward_ecs,
    aws_iam_role_policy_attachment.lambda_policy_attachment
  ]
}

resource "aws_lb_listener_rule" "https_forward_ecs" {
  provider = aws
  for_each = { for rule_key, rule in local.forward_ecs_rules : rule_key => rule }

  listener_arn = aws_lb_listener.https.arn
  priority     = each.value.priority

  dynamic "action" {
    for_each = [for oidc_name, oidc in local.oidc_auth_map : oidc if lookup(each.value, "oidc_authentication", null) == oidc.name]
    content {
      type = "authenticate-oidc"
      authenticate_oidc {
        authorization_endpoint     = action.value.authorization_endpoint
        client_id                  = action.value.client_id
        client_secret              = action.value.client_secret
        issuer                     = action.value.issuer
        token_endpoint             = action.value.token_endpoint
        user_info_endpoint         = action.value.user_info_endpoint
        on_unauthenticated_request = action.value.on_unauthenticated_request
        authentication_request_extra_params = {
          for param in lookup(action.value, "authentication_request_extra_params", {}) : param.key => param.value
        }
        scope               = lookup(action.value, "scope", null)
        session_cookie_name = lookup(action.value, "session_cookie_name", null)
        session_timeout     = lookup(action.value, "session_timeout", null)
      }
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_target_group[each.key].arn
  }

  condition {
    path_pattern {
      values = [each.value.path]
    }
  }

  condition {
    host_header {
      values = concat(
        [lookup(each.value, "domain_prefix", "") != "" ? "${lookup(each.value, "domain_prefix", "")}.${local.unique_domain}" : local.unique_domain],
        [for domain_key, domain in lookup(var.instance.spec, "additional_domains", {}) : lookup(each.value, "domain_prefix", "") != "" ? "${lookup(each.value, "domain_prefix", "")}.${domain.domain}" : domain.domain]
      )
    }
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  provider = aws
  name     = length("${var.environment.unique_name}-${var.instance_name}-lambda-exec-role") > 64 ? "a${substr(md5("${var.environment.unique_name}-${var.instance_name}-lambda-exec-role"), 1, 63)}" : "${var.environment.unique_name}-${var.instance_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  provider    = aws
  name        = length("${var.environment.unique_name}-${var.instance_name}-lambda-policy") > 64 ? "a${substr(md5("${var.environment.unique_name}-${var.instance_name}-lambda-policy"), 1, 63)}" : "${var.environment.unique_name}-${var.instance_name}-lambda-policy"
  description = "IAM policy for Lambda to manage ECS services"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:DescribeTaskDefinition"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  provider   = aws
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/ecs-lambda-fn"
  output_path = "${path.module}/${var.environment.unique_name}-${var.instance_name}-lambda_function.zip"
}

resource "aws_lambda_function" "ecs_rule_manager" {
  provider         = aws
  filename         = "${path.module}/${var.environment.unique_name}-${var.instance_name}-lambda_function.zip"
  function_name    = length("${var.environment.unique_name}-${var.instance_name}-ecs-rule-manager") > 64 ? "a${substr(md5("${var.environment.unique_name}-${var.instance_name}-ecs-rule-manager"), 1, 63)}" : "${var.environment.unique_name}-${var.instance_name}-ecs-rule-manager"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.8"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  reserved_concurrent_executions = 1

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  tags = {
    "Name" = "${var.environment.unique_name}-${var.instance_name}-ecs-rule-manager"
  }
}

resource "aws_security_group" "ecs_alb_sg" {
  provider    = aws
  name        = length("${var.environment.unique_name}-${var.instance_name}-alb-sg") > 255 ? "a${substr(md5("${var.environment.unique_name}-${var.instance_name}-alb-sg"), 1, 254)}" : "${var.environment.unique_name}-${var.instance_name}-alb-sg"
  description = "Security group for ${var.environment.unique_name}-${var.instance_name} ALB"
  vpc_id      = var.inputs.network_details.attributes.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.instance.spec.public ? ["0.0.0.0/0"] : [var.inputs.network_details.attributes.vpc_cidr_block]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.instance.spec.public ? ["0.0.0.0/0"] : [var.inputs.network_details.attributes.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "${var.environment.unique_name}-${var.instance_name}-alb-sg"
  }
}

resource "aws_lb" "ecs_alb" {
  provider                   = aws
  name                       = length("${var.environment.unique_name}-${var.instance_name}-alb") > 32 ? "a${substr(md5("${var.environment.unique_name}-${var.instance_name}"), 1, 31)}" : "${var.environment.unique_name}-${var.instance_name}-alb"
  internal                   = !var.instance.spec.public
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.ecs_alb_sg.id]
  subnets                    = local.subnets
  enable_deletion_protection = false
  tags = {
    "Name" = "${var.environment.unique_name}-${var.instance_name}-alb"
  }
}

resource "aws_lb_listener" "http" {
  provider          = aws
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_target_group" "ecs_target_group" {
  provider = aws
  for_each = { for rule_key, rule in local.forward_ecs_rules : rule_key => rule }

  name        = length("${var.environment.unique_name}-${var.instance_name}-${each.key}-${each.value.port}-tg") > 32 ? "a${substr(md5("${var.environment.unique_name}-${var.instance_name}-${each.key}-${each.value.port}"), 1, 31)}" : "${var.environment.unique_name}-${var.instance_name}-${each.key}-${each.value.port}-tg"
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = var.inputs.network_details.attributes.vpc_id
  target_type = "ip"

  health_check {
    protocol            = lookup(lookup(each.value, "health_check", {}), "protocol", "HTTP")
    path                = lookup(lookup(each.value, "health_check", {}), "path", "/")
    matcher             = lookup(lookup(each.value, "health_check", {}), "matcher", "200-499")
    interval            = lookup(lookup(each.value, "health_check", {}), "interval", 30)
    timeout             = lookup(lookup(each.value, "health_check", {}), "timeout", 5)
    healthy_threshold   = lookup(lookup(each.value, "health_check", {}), "healthy_threshold", 2)
    unhealthy_threshold = lookup(lookup(each.value, "health_check", {}), "unhealthy_threshold", 2)
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    "Name" = "${var.environment.unique_name}-${var.instance_name}-${each.key}-${each.value.port}-tg"
  }
}

resource "aws_lb_listener" "https" {
  provider          = aws
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-2016-08"
  certificate_arn = var.instance.spec.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Default HTTPS response"
      status_code  = "200"
    }
  }
}

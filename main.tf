module "certificate" {
  source    = "armorfret/acm-certificate/aws"
  version   = "0.0.1"
  hostnames = ["${var.domain}"]
}

module "lambda" {
  source  = "armorfret/lambda/aws"
  version = "0.0.1"

  lambda-bucket  = "${var.lambda-bucket}"
  lambda-version = "${var.version}"
  function-name  = "s3authproxy_lambda_${var.data-bucket}"

  environment-variables = {
    S3_BUCKET = "${var.config-bucket}"
    S3_KEY    = "config.yaml"
  }

  access-policy-document = "${data.aws_iam_policy_document.lambda_perms.json}"
  trust-policy-document  = "${data.aws_iam_policy_document.lambda_assume.json}"

  source-arns = ["arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api.id}/*"]
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_api_gateway_rest_api" "api" {
  name = "s3authproxy-${var.data-bucket}"
}

resource "aws_api_gateway_resource" "endpoint" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "{story}"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.endpoint.id}"
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method_settings" "settings" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  stage_name  = "${aws_api_gateway_deployment.deployment.stage_name}"
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.endpoint.id}"
  http_method             = "${aws_api_gateway_method.method.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${module.lambda.invoke_arn}"
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    "aws_api_gateway_method.method",
    "aws_api_gateway_integration.integration",
  ]

  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  stage_name  = "prod"

  variables {
    bucket = "${var.data-bucket}"
  }
}

resource "aws_api_gateway_domain_name" "domain" {
  domain_name     = "${var.domain}"
  certificate_arn = "${module.certificate.arn}"
}

resource "aws_api_gateway_base_path_mapping" "mapping" {
  api_id      = "${aws_api_gateway_rest_api.api.id}"
  stage_name  = "${aws_api_gateway_deployment.deployment.stage_name}"
  domain_name = "${aws_api_gateway_domain_name.domain.domain_name}"
}

module "publish-user" {
  source         = "armorfret/s3-publish/aws"
  version        = "0.0.1"
  logging-bucket = "${var.logging-bucket}"
  publish-bucket = "${var.data-bucket}"
}

module "config-user" {
  source         = "armorfret/s3-publish/aws"
  version        = "0.0.1"
  logging-bucket = "${var.logging-bucket}"
  publish-bucket = "${var.config-bucket}"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"

      identifiers = [
        "lambda.amazonaws.com",
        "apigateway.amazonaws.com",
      ]
    }
  }
}

data "aws_iam_policy_document" "lambda_perms" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${var.data-bucket}/*",
      "arn:aws:s3:::${var.data-bucket}",
      "arn:aws:s3:::${var.config-bucket}/*",
      "arn:aws:s3:::${var.config-bucket}",
    ]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:*:*:*",
    ]
  }
}

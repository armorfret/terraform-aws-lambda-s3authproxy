terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

module "apigw" {
  source  = "armorfret/apigw-lambda/aws"
  version = "0.10.0"

  source_bucket  = var.lambda_bucket
  source_version = var.lambda_version
  function_name  = "s3authproxy_${var.config_bucket}"

  environment_variables = {
    S3_BUCKET = var.config_bucket
    S3_KEY    = "config.yaml"
  }

  stage_variables = {
    bucket = var.data_bucket
  }

  access_policy_document = data.aws_iam_policy_document.lambda_perms.json

  hostname = var.hostname

  cloudwatch_retention_in_days = var.cloudwatch_retention_in_days
}

module "publish_user" {
  source         = "armorfret/s3-publish/aws"
  version        = "0.9.0"
  logging_bucket = var.logging_bucket
  publish_bucket = var.data_bucket
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = module.publish_user.publish_bucket

  rule {
    id     = "expiry"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

module "config_user" {
  source         = "armorfret/s3-publish/aws"
  version        = "0.9.0"
  logging_bucket = var.logging_bucket
  publish_bucket = var.config_bucket
}

data "aws_iam_policy_document" "lambda_perms" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${var.data_bucket}/*",
      "arn:aws:s3:::${var.data_bucket}",
      "arn:aws:s3:::${var.config_bucket}/*",
      "arn:aws:s3:::${var.config_bucket}",
    ]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
    ]

    resources = [
      "arn:aws:logs:*:*:log-group:/aws/lambda/s3authproxy_${var.config_bucket}",
    ]
  }

  statement {
    actions = [
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:*:*:log-group:/aws/lambda/s3authproxy_${var.config_bucket}:*",
    ]
  }
}

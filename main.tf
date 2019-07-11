module "apigw" {
  source  = "armorfret/apigw-lambda/aws"
  version = "0.0.3"

  source_bucket  = "${var.lambda_bucket}"
  source_version = "${var.lambda_version}"
  function_name  = "s3authproxy_${var.config_bucket}"

  environment_variables = {
    S3_BUCKET = "${var.config_bucket}"
    S3_KEY    = "config.yaml"
  }

  stage_variables = {
    bucket = "${var.data_bucket}"
  }

  access_policy_document = "${data.aws_iam_policy_document.lambda_perms.json}"

  hostname = "${var.hostname}"
}

module "publish_user" {
  source         = "armorfret/s3-publish/aws"
  version        = "0.0.2"
  logging_bucket = "${var.logging_bucket}"
  publish_bucket = "${var.data_bucket}"
}

module "config_user" {
  source         = "armorfret/s3-publish/aws"
  version        = "0.0.2"
  logging_bucket = "${var.logging_bucket}"
  publish_bucket = "${var.config_bucket}"
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
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:*:*:*",
    ]
  }
}

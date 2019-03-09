output "dns-name" {
  value = "${aws_api_gateway_domain_name.domain.cloudfront_domain_name}"
}

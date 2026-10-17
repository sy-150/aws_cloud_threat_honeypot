# Creating ACM Certificate
# DNS Validation
resource "aws_acm_certificate" "project-acm" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  # Creates a new certificate before destroying an old one
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "Project-ACM"
  }
}

# Validating the ACM Certificate
resource "aws_route53_record" "cert_validation" {
  # Data transformation
  # for_each only accepts a Map or Set of Strings
  # Using for dvo in ... : dvo.domain_name => { ... } (Map Comprehension)
  # converts the objects into a key-value map
  for_each = {
    for dvo in aws_acm_certificate.project-acm.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  # Prevents pipeline failure if a former CNAME validation record has not been deleted yet
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Validates the pending certificate
resource "aws_acm_certificate_validation" "project_cert_validation" {
  certificate_arn         = aws_acm_certificate.project-acm.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
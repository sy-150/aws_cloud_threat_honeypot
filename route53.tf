# Defining the route 53 DNS with data
# Prevents terraform from destroying?
# Reduces the hassle of manually copy pasting NS everytime terraform is applied from a destroyed state
data "aws_route53_zone" "main" {
  name = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "name" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.project-lb.dns_name # ALB DNS name
    zone_id                = aws_lb.project-lb.zone_id  # ALB Canonical Hosted Zone ID
    evaluate_target_health = true
  }
}
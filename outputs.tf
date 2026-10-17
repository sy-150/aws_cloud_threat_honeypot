# Website URL used for testing
output "website_url" {
  description = "Website URL"
  value       = "https://${aws_route53_record.name.name}"
}

# ALB DNS to differentiate server and domain issues
output "alb_dns_name" {
  description = "DNS Name of the Application Load Balancer"
  value       = aws_lb.project-lb.dns_name
}

# Threat analyzer to process attack data without burdening EC2
output "lambda_threat_analyzer_url" {
  description = "Endpoint On-Demand Lambda Payload Analyzer"
  value       = aws_lambda_function_url.payload_analyzer_url.function_url
}
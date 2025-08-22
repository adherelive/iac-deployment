# modules/route53/main.tf - Route53 Module

# Data source for existing hosted zone
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# A record for the subdomain
resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }

}

# Health check for the application
resource "aws_route53_health_check" "main" {
  fqdn                            = "${var.subdomain}.${var.domain_name}"
  port                            = 443
  type                            = "HTTPS"
  resource_path                   = "/"
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_alarm_region         = "ap-south-1"
  cloudwatch_alarm_name           = "${var.subdomain}-${var.domain_name}-health-check"
  insufficient_data_health_status = "Unhealthy"

  tags = merge(var.tags, {
    Name = "${var.subdomain}.${var.domain_name} Health Check"
  })
}

# CloudWatch alarm for health check
resource "aws_cloudwatch_metric_alarm" "health_check" {
  alarm_name          = "${var.subdomain}-${var.domain_name}-health-check"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "This metric monitors health check status"
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.main.id
  }

  tags = var.tags
}
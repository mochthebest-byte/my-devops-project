# ══════════════════════════════════════════════════════════
#  Route53 — DNS зона для домену
# ══════════════════════════════════════════════════════════
#
#  Використовується:
#    - ExternalDNS: автоматично створює A/AAAA записи для Gateway
#    - cert-manager: DNS-01 челендж для Let's Encrypt
#
#  ⚠️  Перед terraform apply:
#      У реєстраторі домену вказати NS-записи з output нижче.

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = merge(var.tags, {
    Name = "${var.project_name}-dns"
  })
}

# ══════════════════════════════════════════════════════════
#  ACM (Certificate Manager) — для HTTPS listener Gateway
# ══════════════════════════════════════════════════════════
#
#  Створює wildcard-сертифікат *.domain.name
#  через DNS-01 валідацію (Route53).

resource "aws_acm_certificate" "wildcard" {
  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

# ╠════ ACM Validation — АКТИВНО ════════════════════════════
#  Сертифікат створено, CNAME-записи додано в Route53.
#  Валідація виконується автоматично через DNS-01.
#  ⚠️  Домен має бути делеговано на NS-сервери Route53:
#     terraform output dns_nameservers

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

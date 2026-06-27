# ══════════════════════════════════════════════════════════
#  AWS Budget — контроль витрат
# ══════════════════════════════════════════════════════════
#
#  Попереджає, коли витрати перевищують пороги.
#  Для навчального проекту: жорсткий ліміт, щоб не палити гроші.
#
#  ⚠️  Потрібно ввімкнути Budgets в AWS:
#      https://console.aws.amazon.com/billing/home?#/budgets

resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = "50.0" # $50 на місяць (EKS + ALB + NAT)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80 # 80% = $40
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["admin@example.com"] # ⚠️ Замінити на реальний email
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100 # 100% = $50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["admin@example.com"] # ⚠️ Замінити на реальний email
  }

  tags = var.tags
}

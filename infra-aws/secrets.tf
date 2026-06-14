# ══════════════════════════════════════════════════════════
#  Secrets Manager — Grafana OIDC client secret
# ══════════════════════════════════════════════════════════
#
#  The grafana-oidc ExternalSecret (k8s/grafana-oidc-external-secret.yaml)
#  reads from this path and creates a K8s Secret consumed by:
#    - Grafana (via envValueFrom)
#    - Keycloak realm import (bootstrap only — see ConfigMap comment)

resource "random_password" "grafana_oidc" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "grafana_oidc" {
  name                    = "/my-app/grafana-oidc"
  recovery_window_in_days = 0 # дозволяє terraform destroy видалити одразу
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "grafana_oidc" {
  secret_id = aws_secretsmanager_secret.grafana_oidc.id
  secret_string = jsonencode({
    client-secret = random_password.grafana_oidc.result
  })
}

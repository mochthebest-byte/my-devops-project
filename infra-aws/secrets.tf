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

# ══════════════════════════════════════════════════════════
#  Secrets Manager — PostgreSQL (voting-app + keycloak)
# ══════════════════════════════════════════════════════════
#
#  The postgresql ExternalSecret reads from this path and
#  creates a K8s Secret consumed by:
#    - Bitnami PostgreSQL (voting-app, secret "postgresql")
#    - Bitnami PostgreSQL (keycloak, via keycloak-db ExternalSecret)

resource "random_password" "postgresql" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "postgresql" {
  name                    = "/my-app/postgresql"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "postgresql" {
  secret_id = aws_secretsmanager_secret.postgresql.id
  secret_string = jsonencode({
    password          = random_password.postgresql.result
    postgres-password = random_password.postgresql.result
  })
}

# ══════════════════════════════════════════════════════════
#  Secrets Manager — Keycloak admin password (bootstrapping)
# ══════════════════════════════════════════════════════════

resource "random_password" "keycloak_admin" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "keycloak_admin" {
  name                    = "/my-app/keycloak-admin"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "keycloak_admin" {
  secret_id = aws_secretsmanager_secret.keycloak_admin.id
  secret_string = jsonencode({
    admin-password = random_password.keycloak_admin.result
  })
}

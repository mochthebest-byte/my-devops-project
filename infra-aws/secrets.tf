# ═══════════════════════════════════════════════════════════════
#  Secrets Manager — managed secrets (not in Git YAML)
# ═══════════════════════════════════════════════════════════════
#  Всі k8s Secret ресурси створюються через ExternalSecret,
#  які тягнуть значення з AWS Secrets Manager.
#  Жоден секрет не зберігається у відкритому вигляді в Git.
#
#  ⚠️  Grafana OIDC secret має співпадати з client secret
#      у Keycloak realm (myapp-realm.json). Після першого
#      terraform apply: оновіть realm JSON або AWS Secret,
#      щоб значення синхронізувались.
# ═══════════════════════════════════════════════════════════════

# ── Random initial values — перевизначаються в Secrets Manager ──
resource "random_password" "grafana_oidc_client_secret" {
  length  = 32
  special = false
}

resource "random_password" "keycloak_db_password" {
  length  = 24
  special = false
}

# ── /my-app/grafana-oidc ──────────────────────────────────────
resource "aws_secretsmanager_secret" "grafana_oidc" {
  name        = "/my-app/grafana-oidc"
  description = "Grafana OIDC client secret (must match Keycloak realm)"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "grafana_oidc" {
  secret_id = aws_secretsmanager_secret.grafana_oidc.id
  secret_string = jsonencode({
    client-secret = random_password.grafana_oidc_client_secret.result
  })
}

# ── /my-app/keycloak-db ───────────────────────────────────────
resource "aws_secretsmanager_secret" "keycloak_db" {
  name        = "/my-app/keycloak-db"
  description = "Keycloak PostgreSQL database password"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "keycloak_db" {
  secret_id = aws_secretsmanager_secret.keycloak_db.id
  secret_string = jsonencode({
    password = random_password.keycloak_db_password.result
  })
}

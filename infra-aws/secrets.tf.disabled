# Secrets Manager - managed secrets (not in Git YAML)
#
# All k8s Secret resources are created via ExternalSecret,
# pulling values from AWS Secrets Manager.
# No secrets are stored in plain text in Git.
#
# Note: Grafana OIDC secret must match the client secret
# in the Keycloak realm (myapp-realm.json). After the first
# terraform apply, update either the realm JSON or the AWS Secret
# to keep them in sync.

# Random initial values - overridable in Secrets Manager console
resource "random_password" "grafana_oidc_client_secret" {
  length  = 32
  special = false
}

resource "random_password" "keycloak_db_password" {
  length  = 24
  special = false
}

# /my-app/grafana-oidc
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

# /my-app/keycloak-db
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

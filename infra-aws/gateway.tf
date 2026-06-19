# ══════════════════════════════════════════════════════════
#  Gateway API — керується через ArgoCD, а не Terraform
# ══════════════════════════════════════════════════════════
#
#  Terraform керує тільки інфраструктурою:
#    - IAM + Helm AWS Load Balancer Controller → addons.tf
#
#  Усі Gateway-ресурси (GatewayClass, Gateway, HTTPRoute):
#    → charts/gateway-config/ (ArgoCD Application: gateway-config)
#
#  🔄 Якщо GatewayClass потрібен до встановлення ArgoCD,
#     застосувати вручну: helm template charts/gateway-config | kubectl apply -f -

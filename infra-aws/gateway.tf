# ══════════════════════════════════════════════════════════
#  Gateway API — ресурси перенесено в k8s/gateway-config.yaml
#  (керується через ArgoCD, а не Terraform kubectl_manifest)
# ══════════════════════════════════════════════════════════
#
#  Terraform керує тільки інфраструктурою:
#    - IAM + Helm AWS Load Balancer Controller → addons.tf
#
#  Усі Gateway-ресурси (GatewayClass, Gateway, HTTPRoute):
#    → k8s/gateway-config.yaml (ArgoCD Application: gateway-config)
#
#  🔄 Якщо GatewayClass потрібен до встановлення ArgoCD,
#     застосувати вручну: kubectl apply -f k8s/gateway-config.yaml

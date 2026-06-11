# ══════════════════════════════════════════════════════════
#  Gateway API — створює ALB + маршрутизацію
# ══════════════════════════════════════════════════════════

# GatewayClass — встановлюється AWS LB Controller
resource "kubectl_manifest" "gateway_class" {
  yaml_body = <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: aws-lb-gateway
spec:
  controllerName: gateway.k8s.aws/alb
  description: "AWS ALB Gateway — створює ALB"
YAML
  depends_on = [helm_release.lb_controller]
}

# Gateway — публічний ALB
resource "kubectl_manifest" "gateway" {
  yaml_body = <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: voting-app-gateway
  namespace: voting-app
  annotations:
    # Тип балансувальника
    alb.ingress.kubernetes.io/scheme: internet-facing
    # Без статичної IP (або використовуй EIP)
    alb.ingress.kubernetes.io/target-type: ip
spec:
  gatewayClassName: aws-lb-gateway
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: Same
YAML
  depends_on = [kubectl_manifest.gateway_class]
}

# HTTPRoute — vote.mochthebest.io
resource "kubectl_manifest" "vote_route" {
  yaml_body = <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: vote-route
  namespace: voting-app
spec:
  parentRefs:
  - name: voting-app-gateway
    sectionName: http
  hostnames:
  - vote.${var.domain_name}
  rules:
  - backendRefs:
    - name: vote
      port: 5000
YAML
  depends_on = [kubectl_manifest.gateway]
}

# HTTPRoute — result.mochthebest.io
resource "kubectl_manifest" "result_route" {
  yaml_body = <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: result-route
  namespace: voting-app
spec:
  parentRefs:
  - name: voting-app-gateway
    sectionName: http
  hostnames:
  - result.${var.domain_name}
  rules:
  - backendRefs:
    - name: result
      port: 81
YAML
  depends_on = [kubectl_manifest.gateway]
}

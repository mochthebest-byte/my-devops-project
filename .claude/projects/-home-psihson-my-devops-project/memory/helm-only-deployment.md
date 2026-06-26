---
name: helm-only-deployment
description: All infrastructure deployment must go through Helm, never kubectl apply or manual manifests
metadata:
  type: feedback
---

All infrastructure in this project MUST be deployed through Helm. No kubectl apply, no manual manifests, no argocd CLI.

**Exceptions:**
- Bootstrap secrets for External Secrets Operator (ESO) if it can't reach AWS Secrets Manager

**How to apply:**

For resources that need to be created (namespaces, configmaps, etc.), create a minimal Helm chart:
1. Create `charts/<name>/Chart.yaml`
2. Create `charts/<name>/templates/<resource>.yaml`
3. Install with: `helm upgrade --install <name> ./charts/<name> --namespace <ns> --create-namespace`

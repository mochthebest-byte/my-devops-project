#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  Production-grade CI tests for voting-app
#
#  Особливості:
#  • Замість sleep — чекаємо реальної готовності через:
#    1. kubectl rollout status (деплой)
#    2. kubectl wait --for=condition=Ready (поди)
#    3. HTTP retry-цикл (сама апка)
#  • На кожному етапі виводимо діагностику при помилці
#  • Наприкінці тесту — автоматичний dump логів при падінні
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

NAMESPACE="${NAMESPACE:-voting-app}"
TIMEOUT="${TIMEOUT:-120}"          # загальний таймаут на rollout (сек)
RETRY_DELAY="${RETRY_DELAY:-2}"    # початковий інтервал між спробами
MAX_BACKOFF="${MAX_BACKOFF:-16}"   # максимальний backoff (сек)
VOTE_CHECK_TIMEOUT="${VOTE_CHECK_TIMEOUT:-45}"  # скільки чекати на результат голосу

# Імена деплоїв — налаштовуються під різні оточення
# (docker-compose: vote/result/worker, EKS: voting-app-vote/result/worker)
DEPLOY_VOTE="${DEPLOY_VOTE:-vote}"
DEPLOY_RESULT="${DEPLOY_RESULT:-result}"
DEPLOY_WORKER="${DEPLOY_WORKER:-worker}"

# Kubernetes service names / URLs
SERVICE_VOTE="${SERVICE_VOTE:-vote}"
SERVICE_VOTE_PORT="${SERVICE_VOTE_PORT:-80}"
SERVICE_RESULT="${SERVICE_RESULT:-result}"

# ── Колірний вивід ──────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Функція: dump логів + статус подів при помилці ────────
dump_diagnostics() {
  local context="${1:-unknown}"
  echo ""
  error "╔════════════════════════════════════════════════════"
  error "║  DIAGNOSTICS — ${context}"
  error "╚════════════════════════════════════════════════════"

  echo ""
  info "--- Pod status in namespace '${NAMESPACE}' ---"
  kubectl get pods -n "${NAMESPACE}" -o wide 2>&1 || true

  echo ""
  info "--- Deployments in namespace '${NAMESPACE}' ---"
  kubectl get deployments -n "${NAMESPACE}" 2>&1 || true

  # Логи останніх 50 рядків від усіх relevant подів
  for deployment in "${DEPLOY_VOTE}" "${DEPLOY_RESULT}" "${DEPLOY_WORKER}"; do
    echo ""
    info "--- Last 50 lines of logs: deployment/${deployment} ---"
    # Спочатку exact match, потім fallback на app.kubernetes.io/name,
    # потім app=, потім просто беремо перший под з деплою
    if ! kubectl logs -n "${NAMESPACE}" \
         -l "app.kubernetes.io/name=${deployment}" \
         --tail=50 --prefix=true 2>&1; then
      # Fallback: pod label = short name (vote/result/worker)
      short_name="${deployment##*-}"  # беремо останній сегмент після останнього '-'
      short_name="${short_name:-${deployment}}"
      kubectl logs -n "${NAMESPACE}" \
        -l "app.kubernetes.io/name=${short_name}" \
        --tail=50 --prefix=true 2>&1 || \
      kubectl logs -n "${NAMESPACE}" \
        -l "app=${deployment}" \
        --tail=50 --prefix=true 2>&1 || \
      kubectl logs -n "${NAMESPACE}" \
        -l "app=${short_name}" \
        --tail=50 --prefix=true 2>&1 || \
      echo "(no logs found for ${deployment})"
    fi
  done

  # Останні події
  echo ""
  info "--- Recent events in namespace ---"
  kubectl get events -n "${NAMESPACE}" --sort-by='.lastTimestamp' \
    --field-selector type!=Normal 2>&1 | tail -20 || true
}

# ── Функція: retry HTTP GET з експоненційним backoff ──────
http_get_with_retry() {
  local url="$1"
  local pattern="$2"
  local max_attempts="$3"
  local delay="${RETRY_DELAY}"
  local attempt=0

  while [ "${attempt}" -lt "${max_attempts}" ]; do
    attempt=$((attempt + 1))
    if curl -sS "${url}" 2>/dev/null | grep -q "${pattern}"; then
      return 0
    fi
    info "  Retry ${attempt}/${max_attempts} — waiting for '${pattern}' at ${url} (backoff: ${delay}s)"
    sleep "${delay}"
    # Exponential backoff, capped at MAX_BACKOFF
    delay=$((delay * 2))
    if [ "${delay}" -gt "${MAX_BACKOFF}" ]; then
      delay="${MAX_BACKOFF}"
    fi
  done
  return 1
}

# ═══════════════════════════════════════════════════════════
#  КРОК 1: Чекаємо готовності деплоїв
# ═══════════════════════════════════════════════════════════
echo ""
info "╔════════════════════════════════════════════════════"
info "║  PHASE 1: Wait for deployments to be ready"
info "╚════════════════════════════════════════════════════"

for deployment in "${DEPLOY_VOTE}" "${DEPLOY_RESULT}" "${DEPLOY_WORKER}"; do
  echo ""
  info "Waiting for deployment/${deployment} rollout (timeout=${TIMEOUT}s)..."
  if ! kubectl rollout status "deployment/${deployment}" \
       -n "${NAMESPACE}" --timeout="${TIMEOUT}s"; then
    error "❌ deployment/${deployment} failed to roll out"
    dump_diagnostics "deployment/${deployment} rollout failed"
    exit 1
  fi
  info "✅ deployment/${deployment} is ready"
done

# Double-check: всі поди Ready
echo ""
info "All pods status:"
kubectl wait --for=condition=Ready pods \
  -n "${NAMESPACE}" \
  -l "app.kubernetes.io/instance in (${DEPLOY_VOTE}, ${DEPLOY_RESULT}, ${DEPLOY_WORKER})" \
  --timeout="${TIMEOUT}s" 2>&1 || \
kubectl wait --for=condition=Ready pods \
  -n "${NAMESPACE}" \
  -l "app in (${DEPLOY_VOTE}, ${DEPLOY_RESULT}, ${DEPLOY_WORKER})" \
  --timeout="${TIMEOUT}s" 2>&1 || {
    error "❌ Some pods are not Ready"
    dump_diagnostics "pods not ready"
    exit 1
  }

# ═══════════════════════════════════════════════════════════
#  КРОК 2: Перевіряємо, що vote відповідає
# ═══════════════════════════════════════════════════════════
echo ""
info "╔════════════════════════════════════════════════════"
info "║  PHASE 2: Verify vote is serving traffic"
info "╚════════════════════════════════════════════════════"

info "Checking HTTP response from http://${SERVICE_VOTE}:${SERVICE_VOTE_PORT}..."
if ! timeout 10 bash -c "while ! curl -sS -o /dev/null http://${SERVICE_VOTE}:${SERVICE_VOTE_PORT} 2>/dev/null; do sleep 1; done"; then
  error "❌ ${SERVICE_VOTE} service is not responding"
  dump_diagnostics "${SERVICE_VOTE} not responding"
  exit 1
fi
info "✅ vote is serving"

# ═══════════════════════════════════════════════════════════
#  КРОК 3: Голосування + очікування результату
# ═══════════════════════════════════════════════════════════
echo ""
info "╔════════════════════════════════════════════════════"
info "║  PHASE 3: Cast vote and verify result"
info "╚════════════════════════════════════════════════════"

info "Casting vote via POST http://${SERVICE_VOTE}:${SERVICE_VOTE_PORT} → vote=b"
if ! curl -sS -X POST --data "vote=b" "http://${SERVICE_VOTE}:${SERVICE_VOTE_PORT}" > /dev/null; then
  error "❌ Failed to POST vote"
  dump_diagnostics "POST vote failed"
  exit 1
fi
info "✅ Vote cast successfully"

# Чекаємо результат з retry-циклом замість sleep 10
info "Waiting for vote to appear on result page (http://${SERVICE_RESULT})..."
MAX_ATTEMPTS=$((VOTE_CHECK_TIMEOUT / 2))
if http_get_with_retry "http://${SERVICE_RESULT}" "1 vote" "${MAX_ATTEMPTS}"; then
  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════╗"
  echo -e "${GREEN}║          TESTS PASSED ✓                     ║"
  echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
  exit 0
else
  echo ""
  error "╔════════════════════════════════════════════════════"
  error "║  TESTS FAILED ✗ — результат не з'явився "
  error "║  за ${VOTE_CHECK_TIMEOUT} секунд"
  error "╚════════════════════════════════════════════════════"

  dump_diagnostics "tests failed — result not found after timeout"

  # Фінальна спроба — показати що повернув result
  echo ""
  info "--- Raw result page content ---"
  curl -sS "http://${SERVICE_RESULT}" 2>&1 | head -20 || true

  exit 1
fi

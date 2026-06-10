#!/bin/bash
# ══════════════════════════════════════════════════════════
#  Pinggy Tunnel — автоматичне перестворення кожні 59 хв
#  Прокидає локальний Ingress-nginx через SSH тунель
# ══════════════════════════════════════════════════════════
set -euo pipefail

INGRESS_NAME="${1:-voting-app-ingress}"
NAMESPACE="${2:-voting-app}"
BACKEND_SERVICE="${3:-vote}"
BACKEND_PORT="${4:-5000}"
LOG_FILE="${5:-$HOME/pinggy-auto.log}"
PID_FILE="/tmp/pinggy-tunnel.pid"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

cleanup() {
  log "Stopping pinggy tunnel..."
  if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
  fi
  pkill -f "a.pinggy.io" 2>/dev/null || true
}

start_tunnel() {
  # Генеруємо унікальний ідентифікатор для pinggy
  # (щоб уникнути конфліктів з попередніми сесіями)
  local ts=$(date +%s)

  # Запускаємо SSH тунель у фоні
  ssh -p 443 \
    -o StrictHostKeyChecking=no \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -o ExitOnForwardFailure=yes \
    -o LogLevel=QUIET \
    -R0:localhost:80 \
    a.pinggy.io > "$LOG_FILE" 2>&1 &
  local ssh_pid=$!
  echo "$ssh_pid" > "$PID_FILE"

  # Чекаємо появи URL (pinggy пише його в stderr)
  local url=""
  for i in $(seq 1 30); do
    url=$(grep -oP 'https://[a-z0-9-]+\.run\.pinggy-free\.link' "$LOG_FILE" 2>/dev/null | head -1)
    if [ -n "$url" ]; then
      break
    fi
    sleep 1
  done

  echo "$url"
  return 0
}

update_ingress() {
  local url="$1"
  local hostname="${url#https://}"
  hostname="${hostname%%/*}"

  log "Новий URL: $url"
  log "Hostname: $hostname"

  # Перевіряємо чи Ingress існує
  if ! kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" &>/dev/null; then
    log "ERROR: Ingress $INGRESS_NAME не знайдено!"
    return 1
  fi

  # Перевіряємо чи hostname вже є в правилах
  if kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o json | \
     python3 -c "import json,sys; data=json.load(sys.stdin); rules=[r['host'] for r in data['spec']['rules']]; print('' if '$hostname' in rules else '$hostname')" | \
     grep -q .; then
    # Додаємо нове правило
    kubectl patch ingress "$INGRESS_NAME" -n "$NAMESPACE" --type json -p='[
      {"op":"add","path":"/spec/rules/-","value":{
        "host":"'"$hostname"'",
        "http":{"paths":[{
          "path":"/",
          "pathType":"Prefix",
          "backend":{"service":{"name":"'$BACKEND_SERVICE'","port":{"number":$BACKEND_PORT}}}
        }]}
      }}
    ]' || true
    log "✅ Додано правило для $hostname → $BACKEND_SERVICE:$BACKEND_PORT"
  else
    log "ℹ️  $hostname вже є в правилах ingress"
  fi
}

verify() {
  local url="$1"
  if command -v curl &>/dev/null; then
    local code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$url" 2>/dev/null || echo "000")
    log "📊 Перевірка: HTTP $code"
    [ "$code" = "200" ] || [ "$code" = "302" ] || [ "$code" = "301" ]
    return $?
  fi
  return 0
}

# ─── Main Loop ──────────────────────────────────────────
trap cleanup EXIT INT TERM
cleanup
log "════════════════════════════════════════════"
log "🚀 Pinggy Tunnel — старт"
log "    Ingress: $NAMESPACE/$INGRESS_NAME"
log "    Backend: $BACKEND_SERVICE:$BACKEND_PORT"
log "════════════════════════════════════════════"

while true; do
  log "--- Нова сесія ---"

  url=$(start_tunnel)
  if [ -z "$url" ]; then
    log "❌ Не вдалося отримати URL від pinggy, спроба за 10 сек..."
    sleep 10
    continue
  fi

  update_ingress "$url"

  if verify "$url"; then
    log "🎉 Тунель активний: $url"
    log "⏳ Оновлення через 59 хвилин..."
  else
    log "⚠️  Тунель працює, але перевірка не пройшла (може ingress ще не підхопив)"
  fi

  # Чекаємо 59 хвилин (3540 секунд)
  sleep 3540

  log "🔄 Завершення старої сесії..."
  cleanup
  sleep 2
done

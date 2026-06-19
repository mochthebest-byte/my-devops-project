#!/bin/bash
# ⚠️ HACK — runtime patching. Не використовувати в production. Для локальної розробки/демо.
# ══════════════════════════════════════════════════════════
#  Pinggy All-in-One — 4 тунелі, 1 команда
#
#  Запускає одночасно vote, result, grafana, keycloak
#  Автоматично додає URL в Ingress
#  Оновлюється кожні 59 хв
# ══════════════════════════════════════════════════════════
set -euo pipefail

LOG_DIR="$HOME/pinggy-tunnels"
mkdir -p "$LOG_DIR"

# ─── Налаштування сервісів ──────────────────────────
# name:port:namespace:ingress:k8s-service
SERVICES=(
  "vote:5000:voting-app:voting-app-ingress:vote"
  "result:81:voting-app:voting-app-ingress:result"
  "grafana:80:monitoring:grafana-ingress:monitoring-grafana"
  "keycloak:8080:keycloak:keycloak-ingress:keycloak"
)

log()  { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_DIR/tunnel-all.log"; }
die()  { log "❌ $*"; exit 1; }
clean() {
  log "🧹 Зупинка всіх тунелів..."
  pkill -f "a.pinggy.io" 2>/dev/null || true
  rm -f "$LOG_DIR"/tunnel-*.pid
}

trap clean EXIT INT TERM

start_tunnel() {
  local name="$1" logfile="$LOG_DIR/tunnel-$name.log" pidfile="$LOG_DIR/tunnel-$name.pid"

  # Старий тунель — вбити
  if [ -f "$pidfile" ]; then
    kill "$(cat "$pidfile")" 2>/dev/null || true
    rm -f "$pidfile"
  fi

  # Новий тунель
  ssh -o StrictHostKeyChecking=no \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -o LogLevel=QUIET \
    -p 443 -R0:localhost:80 \
    a.pinggy.io > "$logfile" 2>&1 &
  local pid=$!
  echo "$pid" > "$pidfile"

  # Чекати URL
  local url=""
  for i in $(seq 1 30); do
    url=$(grep -oP 'https://[a-z0-9-]+\.run\.pinggy-free\.link' "$logfile" 2>/dev/null | head -1)
    [ -n "$url" ] && break
    sleep 1
  done
  echo "$url"
}

add_ingress_rule() {
  local host="$1" svc_name="$2" svc_port="$3" namespace="$4" ingress_name="$5"

  # Перевірити чи hostname вже є
  if kubectl get ingress "$ingress_name" -n "$namespace" -o json 2>/dev/null | \
     python3 -c "import json,sys; d=json.load(sys.stdin); [exit(1) for r in d['spec']['rules'] if r['host']=='$host']" 2>/dev/null; then
    log "➕ Додаю $host → $svc_name:$svc_port"

    # Будуємо JSON для patch (порт передаємо числом)
    local patch_json
    patch_json=$(cat << EOF | tr -d '\n'
[{"op":"add","path":"/spec/rules/-","value":{
  "host":"${host}",
  "http":{"paths":[{
    "path":"/","pathType":"Prefix",
    "backend":{"service":{"name":"${svc_name}","port":{"number":${svc_port}}}}
  }]}
}}]
EOF
)
    kubectl patch ingress "$ingress_name" -n "$namespace" --type json -p="$patch_json" 2>&1 | logger -t tunnel-all || log "⚠️  Помилка додавання $host до ingress"
  else
    log "ℹ️  $host вже є в ingress"
  fi
}

verify_tunnel() {
  local url="$1" name="$2"
  local code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null || echo "000")
  log "📊 $name → HTTP $code"
  [ "$code" != "000" ]
}

# ─── Main ───────────────────────────────────────────
clean
log "═══════════════════════════════════════════════════"
log "🚀 Pinggy All-in-One — старт"
log "═══════════════════════════════════════════════════"

FIRST_RUN=true

while true; do
  log ""
  log "--- Нова сесія ($(date)) ---"

  # Зупинити старі тунелі (крім першого запуску)
  if [ "$FIRST_RUN" = false ]; then
    log "🔄 Перезапуск тунелів..."
    pkill -f "a.pinggy.io" 2>/dev/null || true
    sleep 2
  fi
  FIRST_RUN=false

  # Зібрати всі URL
  declare -A URLS
  for svc in "${SERVICES[@]}"; do
    IFS=":" read -r name port ns ingress svc_name <<< "$svc"
    log "🔌 Стартую $name..."
    url=$(start_tunnel "$name")
    if [ -z "$url" ]; then
      log "❌ $name: не вдалося отримати URL від pinggy"
      continue
    fi
    URLS[$name]="$url"
    log "  ✅ $url"
  done

  log ""
  log "📝 Оновлюю Ingress rules..."

  for svc in "${SERVICES[@]}"; do
    IFS=":" read -r name port ns ingress svc_name <<< "$svc"
    [ -z "${URLS[$name]:-}" ] && continue
    host=$(echo "${URLS[$name]}" | sed 's|https://||')
    add_ingress_rule "$host" "$svc_name" "$port" "$ns" "$ingress"
  done

  # -- Спеціально для Keycloak --
  if [ -n "${URLS[keycloak]:-}" ]; then
    KC_HOST=$(echo "${URLS[keycloak]}" | sed 's|https://||')
    log "🔑 Keycloak hostname → $KC_HOST"
    kubectl set env -n keycloak statefulset/keycloak KC_HOSTNAME="$KC_HOST" 2>/dev/null || true
  fi

  log ""
  log "═══════════════════════════════════════════════════"
  log "📡 Всі тунелі активні!"

  # Вивести підсумок
  for svc in "${SERVICES[@]}"; do
    IFS=":" read -r name port ns ingress svc_name <<< "$svc"
    [ -n "${URLS[$name]:-}" ] && echo "   $name: ${URLS[$name]}"
  done

  log "⏳ Наступне оновлення через 59 хв..."
  log "═══════════════════════════════════════════════════"
  log ""

  # Перевірка
  sleep 10
  for svc in "${SERVICES[@]}"; do
    IFS=":" read -r name port ns ingress svc_name <<< "$svc"
    [ -n "${URLS[$name]:-}" ] && verify_tunnel "${URLS[$name]}" "$name" || true
  done

  # Чекати 59 хвилин
  sleep 3540
done

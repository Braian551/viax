#!/usr/bin/env bash
# rollback_dispatch_docker.sh
# Revierte dispatch-service de Docker a Node directo bajo Supervisor.
# Uso: bash scripts/rollback_dispatch_docker.sh
# Tiempo estimado: < 30 segundos

set -euo pipefail

SERVER="root@76.13.114.194"
DISPATCH_PATH="/var/www/viax/services/dispatch"
SUPERVISOR_CONF="/etc/supervisor/conf.d/viax-dispatch-service.conf"

echo "=== ROLLBACK: Docker -> Node directo ==="

echo "[1/5] Verificando estado actual..."
ssh "$SERVER" "supervisorctl status viax_dispatch_service; redis-cli PUBSUB NUMSUB dispatch:trip_queue"

echo "[2/5] Bajando contenedor Docker..."
ssh "$SERVER" "cd $DISPATCH_PATH && docker compose down 2>/dev/null || true"

echo "[3/5] Restaurando Supervisor a Node directo..."
ssh "$SERVER" "cat > $SUPERVISOR_CONF <<'EOF'
[program:viax_dispatch_service]
directory=/var/www/viax/services/dispatch
command=/usr/bin/env NODE_ENV=production DISPATCH_SERVICE_MODE=hybrid DISPATCH_OFFER_SENT_LOCK_TTL_SEC=15 REDIS_HOST=127.0.0.1 REDIS_PORT=6379 /usr/bin/node src/worker.js
autostart=true
autorestart=true
startsecs=3
stdout_logfile=/var/www/viax/services/dispatch/logs/worker.log
stderr_logfile=/var/www/viax/services/dispatch/logs/worker.err.log
stopasgroup=true
killasgroup=true
EOF
supervisorctl reread
supervisorctl update"

echo "[4/5] Iniciando servicio con Node directo..."
ssh "$SERVER" "supervisorctl start viax_dispatch_service || true"

echo "[5/5] Verificando estado post-rollback..."
ssh "$SERVER" "for intento in 1 2 3 4 5 6 7 8 9 10; do subscribers=\$(redis-cli PUBSUB NUMSUB dispatch:trip_queue | tail -n 1); if [ \"\$subscribers\" = \"1\" ]; then break; fi; sleep 1; done; supervisorctl status viax_dispatch_service; redis-cli PUBSUB NUMSUB dispatch:trip_queue; redis-cli ping; curl -s -w 'Health: %{http_code}' -o /dev/null http://127.0.0.1/health.php; echo; tail -n 10 /var/www/viax/services/dispatch/logs/worker.log"

echo "=== ROLLBACK COMPLETADO ==="
echo "Verificar manualmente:"
echo "  - subscriber = 1"
echo "  - Supervisor RUNNING"
echo "  - Sin errores en worker.log"
#!/bin/bash
# check_tracking_metrics.sh
# Consulta metricas operativas del tracking-service en Redis.
#
# Uso:
#   bash scripts/check_tracking_metrics.sh            -> metricas de hoy
#   bash scripts/check_tracking_metrics.sh 2026-05-03 -> fecha especifica

SERVER="root@76.13.114.194"
DATE="${1:-$(date +%Y-%m-%d)}"

echo "=== METRICAS TRACKING-SERVICE - $DATE ==="
echo ""

REMOTE_COMMAND="
TODAY='$DATE'
TOTAL=\$(redis-cli GET tracking:metrics:total:\$TODAY 2>/dev/null)
PUBLICADOS=\$(redis-cli GET tracking:metrics:puntos_publicados:\$TODAY 2>/dev/null)
ERRORES=\$(redis-cli GET tracking:metrics:errores:\$TODAY 2>/dev/null)
echo \"  Total leidos              : \${TOTAL:-0}\"
echo \"  Puntos publicados         : \${PUBLICADOS:-0}\"
echo \"  Errores                   : \${ERRORES:-0}\"
echo \"\"
echo \"  Stream pendiente realtime : \$(redis-cli XPENDING trip_tracking_stream tracking_realtime_publishers 2>/dev/null | head -1 || echo sin_grupo)\"
echo \"  Sistema: \$(redis-cli ping) | dispatch subscriber=\$(redis-cli PUBSUB NUMSUB dispatch:trip_queue | tail -1)\"
"

if [ -d "/var/www/viax/services/tracking" ]; then
  bash -c "$REMOTE_COMMAND"
else
  ssh "$SERVER" "$REMOTE_COMMAND"
fi

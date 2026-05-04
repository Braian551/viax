#!/bin/bash
# check_pricing_metrics.sh
# Consulta metricas operativas del pricing-service en Redis.
#
# Uso:
#   bash scripts/check_pricing_metrics.sh            -> metricas de hoy
#   bash scripts/check_pricing_metrics.sh 2026-05-02 -> fecha especifica
#
# Que muestra:
#   quotes        -> cotizaciones calculadas por el pricing-service Node
#   surge_applied -> cotizaciones donde el surge fue > 1.0
#   shadow_match  -> resultados que coinciden con el PHP (+/-5%) - meta: 100%
#   shadow_diff   -> resultados que difieren del PHP - si sube, hay bug
#   errors        -> errores de calculo - debe ser 0 en produccion sana
#   total         -> total de solicitudes procesadas

SERVER="root@76.13.114.194"
DATE="${1:-$(date +%Y-%m-%d)}"

echo "=== METRICAS PRICING-SERVICE - $DATE ==="
echo ""

REMOTE_COMMAND="
TODAY='$DATE'
echo \"  Cotizaciones calculadas   : \$(redis-cli GET pricing:metrics:quotes:\$TODAY 2>/dev/null || echo 0)\"
echo \"  Con surge activo          : \$(redis-cli GET pricing:metrics:surge_applied:\$TODAY 2>/dev/null || echo 0)\"
echo \"  Shadow match (+/-5%)      : \$(redis-cli GET pricing:metrics:shadow_match:\$TODAY 2>/dev/null || echo 0)\"
echo \"  Shadow diff (revisar)     : \$(redis-cli GET pricing:metrics:shadow_diff:\$TODAY 2>/dev/null || echo 0)\"
echo \"  Errores de calculo        : \$(redis-cli GET pricing:metrics:errors:\$TODAY 2>/dev/null || echo 0)\"
echo \"  Total procesados          : \$(redis-cli GET pricing:metrics:total:\$TODAY 2>/dev/null || echo 0)\"
echo \"\"
echo \"  Sistema: \$(redis-cli ping) | dispatch subscriber=\$(redis-cli PUBSUB NUMSUB dispatch:trip_queue | tail -1)\"
"

if [ -d "/var/www/viax/services/pricing" ]; then
  bash -c "$REMOTE_COMMAND"
else
  ssh "$SERVER" "$REMOTE_COMMAND"
fi

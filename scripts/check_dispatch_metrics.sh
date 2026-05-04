#!/usr/bin/env bash
set -euo pipefail

# check_dispatch_metrics.sh
# Consulta las metricas operativas del dispatch-service en Redis.
#
# Uso:
#   bash scripts/check_dispatch_metrics.sh             -> metricas de hoy
#   bash scripts/check_dispatch_metrics.sh 2026-05-01 -> metricas de una fecha especifica
#
# Que muestra:
#   offers      -> viajes donde el dispatch encontro conductor y emitio oferta
#   no_driver   -> viajes procesados pero sin conductor elegible disponible
#   duplicates  -> eventos ignorados por el lock anti-duplicacion (TTL 15s)
#   legacy      -> mensajes del worker PHP legacy (trip_id crudo)
#   invalid     -> mensajes no parseables reales que llegaron al canal
#   total       -> suma de offers + no_driver para el dia consultado

SERVER="root@76.13.114.194"
TARGET_DATE="${1:-$(date +%Y-%m-%d)}"

REMOTE_QUERY="TARGET_DATE='$TARGET_DATE'; \
offers=\$(redis-cli --raw GET dispatch:metrics:offers:\$TARGET_DATE 2>/dev/null); \
no_driver=\$(redis-cli --raw GET dispatch:metrics:no_driver:\$TARGET_DATE 2>/dev/null); \
duplicates=\$(redis-cli --raw GET dispatch:metrics:duplicates:\$TARGET_DATE 2>/dev/null); \
legacy=\$(redis-cli --raw GET dispatch:metrics:legacy:\$TARGET_DATE 2>/dev/null); \
invalid=\$(redis-cli --raw GET dispatch:metrics:invalid:\$TARGET_DATE 2>/dev/null); \
total=\$(redis-cli --raw GET dispatch:metrics:total:\$TARGET_DATE 2>/dev/null); \
subscriber=\$(redis-cli --raw PUBSUB NUMSUB dispatch:trip_queue | awk 'END { print \$NF }'); \
echo \"  Ofertas emitidas a conductor : \${offers:-0}\"; \
echo \"  Viajes sin conductor elegible: \${no_driver:-0}\"; \
echo \"  Duplicados bloqueados        : \${duplicates:-0}\"; \
echo \"  Mensajes legacy PHP          : \${legacy:-0}\"; \
echo \"  Mensajes invalidos reales    : \${invalid:-0}\"; \
echo \"  Total eventos procesados     : \${total:-0}\"; \
echo; \
echo \"  Sistema: \$(redis-cli --raw PING) | subscriber=\${subscriber:-0}\""

echo "=== METRICAS DISPATCH-SERVICE - ${TARGET_DATE} ==="
echo

if command -v redis-cli >/dev/null 2>&1 && [ -d /var/www/viax/services/dispatch ]; then
	eval "$REMOTE_QUERY"
else
	ssh "$SERVER" "$REMOTE_QUERY"
fi
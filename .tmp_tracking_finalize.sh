set -e
cd /var/www/viax/backend
DB_HOST=""
DB_PORT="5432"
DB_NAME=""
DB_USER=""
DB_PASS=""
while IFS='=' read -r key value; do
  key=$(printf '%s' "$key" | tr -d ' \r')
  value=$(printf '%s' "$value" | tr -d '\r')
  case "$key" in
    DB_HOST) DB_HOST="$value" ;;
    DB_PORT) DB_PORT="$value" ;;
    DB_NAME) DB_NAME="$value" ;;
    DB_USER) DB_USER="$value" ;;
    DB_PASS) DB_PASS="$value" ;;
  esac
done < config/.env
PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f migrations/048_tracking_stream_upgrade.sql
echo migration_rerun_ok
if command -v supervisorctl >/dev/null 2>&1; then
  supervisorctl reread
  supervisorctl update
  supervisorctl restart viax_tracking_worker:* || supervisorctl start viax_tracking_worker:*
  echo worker_started_supervisor
else
  pkill -f tracking_stream_worker.php || true
  nohup php /var/www/viax/backend/workers/tracking_stream_worker.php >/var/log/viax_tracking_worker.log 2>&1 &
  echo worker_started_nohup
fi
redis-cli XINFO GROUPS trip_tracking_stream || true
redis-cli XLEN trip_tracking_stream || true
ps aux | grep tracking_stream_worker.php | grep -v grep || true
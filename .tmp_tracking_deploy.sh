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
if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
  echo "db_env_missing"
  exit 1
fi
ts=$(date +%Y%m%d_%H%M%S)
mkdir -p backups
PGPASSWORD=$DB_PASS pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -Fc > backups/pre_tracking_stream_${ts}.dump
echo backup_ok:$ts
PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f migrations/048_tracking_stream_upgrade.sql
echo migration_ok
php -l driver/tracking/update.php
php -l user/stream_trip_updates.php
php -l workers/tracking_stream_worker.php
supervisorctl reread
supervisorctl update
supervisorctl restart viax_tracking_worker:* || supervisorctl start viax_tracking_worker:*
redis-cli XINFO GROUPS trip_tracking_stream || true
redis-cli XLEN trip_tracking_stream || true
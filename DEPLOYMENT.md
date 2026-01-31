# Viax Deployment Guide

## Production Server
- **IP**: `76.13.114.194`
- **OS**: Ubuntu 24.04.3 LTS
- **Stack**: Nginx 1.24.0 + PHP 8.3.6 + PostgreSQL 17.7

---

## Quick Commands

### Run in Production (default)
```bash
flutter run
# Uses: http://76.13.114.194
```

### Run in Development (local)
```bash
flutter run --dart-define=API_BASE_URL=http://192.168.18.68/viax/backend
```

### Run on Android Emulator
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2/viax/backend
```

---

## Server Access

```bash
ssh root@76.13.114.194
```

### Service Status
```bash
sudo systemctl status nginx
sudo systemctl status php8.3-fpm
sudo systemctl status postgresql
```

### Health Check
```bash
curl http://76.13.114.194/viax/backend/health.php
```

---

## Database

```bash
# Connect to database
sudo -u postgres psql viax

# List tables
\dt

# Exit
\q
```

---

## File Locations

| Component | Path |
|-----------|------|
| Backend | `/var/www/viax/backend/` |
| Nginx Config | `/etc/nginx/sites-available/viax` |
| PHP Config | `/etc/php/8.3/fpm/php.ini` |
| Backend .env | `/var/www/viax/backend/config/.env` |
| Logs | `/var/log/nginx/` |

---

## Updating Backend

```bash
# From local machine
cd c:\Flutter\viax
scp -r backend/* root@76.13.114.194:/var/www/viax/backend/

# Then on server, fix permissions
ssh root@76.13.114.194 "chown -R www-data:www-data /var/www/viax"
```

---

## Troubleshooting

### Nginx not responding
```bash
nginx -t
sudo systemctl restart nginx
```

### PHP errors
```bash
tail -f /var/log/nginx/error.log
```

### Database connection issues
```bash
sudo -u postgres psql -c "\l"  # List databases
```

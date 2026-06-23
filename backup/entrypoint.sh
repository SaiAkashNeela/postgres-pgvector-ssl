#!/bin/sh
set -e

BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-0 2 * * *}"

echo "[entrypoint] Schedule: $BACKUP_SCHEDULE"

# Write crontab
echo "$BACKUP_SCHEDULE /usr/local/bin/backup.sh >> /var/log/backup.log 2>&1" > /etc/crontabs/root

# Run a backup immediately on first start so you know it works
echo "[entrypoint] Running initial backup..."
/usr/local/bin/backup.sh || echo "[entrypoint] Initial backup failed — check logs"

echo "[entrypoint] Starting cron daemon..."
exec crond -f -l 2 -L /var/log/cron.log

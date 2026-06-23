#!/bin/bash
set -euo pipefail

BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-0 2 * * *}"

echo "[entrypoint] Schedule: $BACKUP_SCHEDULE"
echo "[entrypoint] Backup keep days: ${BACKUP_KEEP_DAYS:-14}"

# Write crontab for BusyBox crond
mkdir -p /etc/crontabs
echo "$BACKUP_SCHEDULE /usr/local/bin/backup.sh >> /proc/1/fd/1 2>&1" > /etc/crontabs/root

# Initial backup on start
echo "[entrypoint] Running initial backup on start..."
/usr/local/bin/backup.sh || echo "[entrypoint] WARNING: Initial backup failed — check config"

echo "[entrypoint] Starting cron daemon..."
exec busybox crond -f -l 8 -L /dev/stdout

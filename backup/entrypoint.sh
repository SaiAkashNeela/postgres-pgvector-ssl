#!/bin/bash
set -euo pipefail

BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-0 2 * * *}"

echo "[entrypoint] Schedule: $BACKUP_SCHEDULE"
echo "[entrypoint] Backup keep days: ${BACKUP_KEEP_DAYS:-7}"

# Write crontab — redirect to stdout/stderr so docker logs captures it
echo "$BACKUP_SCHEDULE /usr/local/bin/backup.sh 2>&1" | crontab -

# Initial backup on start — proves credentials work immediately
echo "[entrypoint] Running initial backup on start..."
/usr/local/bin/backup.sh || echo "[entrypoint] WARNING: Initial backup failed — check config"

echo "[entrypoint] Starting cron daemon..."
# -f = foreground, -l 6 = log level notice
exec crond -f -l 6

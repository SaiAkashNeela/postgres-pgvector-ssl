#!/bin/sh
set -e

log() { echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $*"; }

# Required
: "${POSTGRES_HOST:?POSTGRES_HOST required}"
: "${POSTGRES_USER:?POSTGRES_USER required}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD required}"
: "${S3_BUCKET:?S3_BUCKET required}"

BACKUP_KEEP_DAYS="${BACKUP_KEEP_DAYS:-7}"
S3_PREFIX="${S3_PREFIX:-postgres-backups}"
TIMESTAMP=$(date -u '+%Y%m%d_%H%M%S')

export PGPASSWORD="$POSTGRES_PASSWORD"

# Build aws CLI endpoint arg (for R2 or custom S3-compatible)
AWS_ARGS=""
if [ -n "$S3_ENDPOINT" ]; then
    AWS_ARGS="--endpoint-url $S3_ENDPOINT"
fi

log "Starting backup run"

# Get all non-template databases
DATABASES=$(psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d postgres -tAq \
    -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';")

FAILED=0
for DB in $DATABASES; do
    FILENAME="${TIMESTAMP}_${DB}.sql.gz"
    S3_KEY="${S3_PREFIX}/${FILENAME}"

    log "Dumping $DB..."
    if pg_dump -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$DB" \
        --no-password --clean --if-exists --create --format=plain \
        | gzip -9 \
        | aws s3 cp $AWS_ARGS - "s3://${S3_BUCKET}/${S3_KEY}" \
            --storage-class STANDARD; then
        log "Uploaded $DB -> s3://${S3_BUCKET}/${S3_KEY}"
    else
        log "ERROR: Failed to backup $DB"
        FAILED=$((FAILED + 1))
    fi
done

# Cleanup old backups beyond retention window
log "Cleaning up backups older than ${BACKUP_KEEP_DAYS} days..."
CUTOFF=$(date -u -d "${BACKUP_KEEP_DAYS} days ago" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
    || date -u -v-${BACKUP_KEEP_DAYS}d '+%Y-%m-%dT%H:%M:%SZ')

aws s3 ls $AWS_ARGS "s3://${S3_BUCKET}/${S3_PREFIX}/" \
    | awk '{print $NF}' \
    | while read -r KEY; do
        FILE_DATE=$(echo "$KEY" | grep -oE '^[0-9]{8}' | head -1)
        if [ -n "$FILE_DATE" ]; then
            FILE_TS="${FILE_DATE:0:4}-${FILE_DATE:4:2}-${FILE_DATE:6:2}T00:00:00Z"
            if [ "$FILE_TS" \< "$CUTOFF" ]; then
                log "Deleting old backup: $KEY"
                aws s3 rm $AWS_ARGS "s3://${S3_BUCKET}/${S3_PREFIX}/${KEY}" || true
            fi
        fi
    done

if [ "$FAILED" -gt 0 ]; then
    log "Backup run completed with $FAILED failure(s)"
    exit 1
fi

log "Backup run completed successfully"

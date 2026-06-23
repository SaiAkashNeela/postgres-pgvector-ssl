#!/bin/bash
set -euo pipefail

log()  { echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $*"; }
fail() { log "ERROR: $*" >&2; exit 1; }

# Required
: "${POSTGRES_HOST:?POSTGRES_HOST required}"
: "${POSTGRES_USER:?POSTGRES_USER required}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD required}"
: "${S3_BUCKET:?S3_BUCKET required}"

BACKUP_KEEP_DAYS="${BACKUP_KEEP_DAYS:-14}"
S3_PREFIX="${S3_PREFIX:-postgres-backups}"
TIMESTAMP=$(date -u '+%d_%m_%Y')
PGCONNECT_TIMEOUT=10

export PGPASSWORD="$POSTGRES_PASSWORD"
export PGCONNECT_TIMEOUT

AWS_ARGS=()
[ -n "${S3_ENDPOINT:-}" ] && AWS_ARGS+=(--endpoint-url "$S3_ENDPOINT")

log "Starting backup (host=$POSTGRES_HOST user=$POSTGRES_USER)"

# Verify connection before attempting any dumps
psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d postgres -c '\q' \
    || fail "Cannot connect to postgres at $POSTGRES_HOST"

# Get all non-template, non-system databases
DATABASES=$(psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d postgres -tAq \
    -c "SELECT datname FROM pg_database
        WHERE datistemplate = false
          AND datname NOT IN ('postgres')
        ORDER BY datname;")

[ -z "$DATABASES" ] && fail "No databases found"

FAILED=0
SUCCEEDED=0

for DB in $DATABASES; do
    FILENAME="${DB}_backup_${TIMESTAMP}.dump"
    S3_KEY="${S3_PREFIX}/${FILENAME}"

    log "Dumping $DB -> s3://${S3_BUCKET}/${S3_KEY}"

    # -Fc = custom format: compressed, supports parallel restore & selective restore
    # Stream directly to S3 — pipefail ensures any stage failure is caught
    if pg_dump \
            -h "$POSTGRES_HOST" \
            -U "$POSTGRES_USER" \
            -d "$DB" \
            --no-password \
            --format=custom \
            --compress=9 \
            --lock-wait-timeout=30s \
            --no-privileges \
            --no-owner \
        | aws s3 cp "${AWS_ARGS[@]}" \
            --storage-class STANDARD \
            --expected-size 1 \
            - "s3://${S3_BUCKET}/${S3_KEY}"; then

        SIZE=$(aws s3 ls "${AWS_ARGS[@]}" "s3://${S3_BUCKET}/${S3_KEY}" \
            | awk '{print $3}')
        [ "${SIZE:-0}" -gt 0 ] || fail "$DB backup uploaded as 0 bytes"
        log "OK: $DB ($SIZE bytes)"
        SUCCEEDED=$((SUCCEEDED + 1))
    else
        log "FAILED: $DB"
        FAILED=$((FAILED + 1))
    fi
done

# Prune backups older than retention window
log "Pruning backups older than ${BACKUP_KEEP_DAYS} days..."
CUTOFF=$(date -u -d "@$(($(date -u +%s) - BACKUP_KEEP_DAYS * 86400))" '+%Y%m%d')

aws s3 ls "${AWS_ARGS[@]}" "s3://${S3_BUCKET}/${S3_PREFIX}/" \
    | awk '{print $NF}' \
    | while IFS= read -r KEY; do
        # Extract DD_MM_YYYY from filename pattern: dbname_backup_DD_MM_YYYY.dump
        if [[ "$KEY" =~ _backup_([0-9]{2})_([0-9]{2})_([0-9]{4})\.dump$ ]]; then
            FILE_DATE="${BASH_REMATCH[3]}${BASH_REMATCH[2]}${BASH_REMATCH[1]}"
            if [ "$FILE_DATE" -lt "$CUTOFF" ]; then
                log "Deleting old backup: $KEY"
                aws s3 rm "${AWS_ARGS[@]}" "s3://${S3_BUCKET}/${S3_PREFIX}/${KEY}" || true
            fi
        fi
    done

log "Done: $SUCCEEDED succeeded, $FAILED failed"
[ "$FAILED" -gt 0 ] && exit 1
exit 0

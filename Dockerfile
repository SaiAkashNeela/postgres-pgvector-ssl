ARG POSTGRES_VERSION=16
FROM postgres:${POSTGRES_VERSION}

RUN apt-get update && apt-get install -y openssl sudo ca-certificates jq pgbackrest postgresql-16-pgvector \
    && rm -rf /var/lib/apt/lists/*

RUN echo "postgres ALL=(root) NOPASSWD: /usr/bin/mkdir, /bin/chown, /usr/bin/openssl" > /etc/sudoers.d/postgres

RUN install -d -m 0750 -o postgres -g postgres /etc/pgbackrest

COPY --chmod=755 init-ssl.sh /docker-entrypoint-initdb.d/init-ssl.sh
COPY --chmod=755 pgbackrest-init.sh /docker-entrypoint-initdb.d/99-pgbackrest-init.sh
COPY --chmod=755 pgbackrest-archive-push-wrapper.sh /usr/local/bin/pgbackrest-archive-push-wrapper.sh
COPY --chmod=755 pgbackrest-backup-watcher.sh /usr/local/bin/pgbackrest-backup-watcher.sh
COPY --chmod=755 wrapper.sh /usr/local/bin/wrapper.sh
RUN sed -i 's|tmpfile=$(mktemp /tmp/collation-refresh\.XXXXXX\.sql)|tmpfile=$(mktemp /tmp/collation-refresh.XXXXXX.sql)\n    chmod 644 "$tmpfile"|' /usr/local/bin/wrapper.sh && \
    sed -i 's|gosu postgres psql -v ON_ERROR_STOP=0|gosu postgres psql -v ON_ERROR_STOP=0 -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-postgres}"|' /usr/local/bin/wrapper.sh && \
    sed -i 's|gosu postgres pg_isready -q 2>/dev/null|gosu postgres pg_isready -q -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-postgres}" 2>/dev/null|g' /usr/local/bin/wrapper.sh && \
    sed -i 's|pg_isready -h 127\.0\.0\.1 -p 5432 -U postgres|pg_isready -h 127.0.0.1 -p 5432 -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-postgres}"|' /usr/local/bin/wrapper.sh && \
    sed -i 's|psql -U "${PGUSER:-postgres}" -tAXq|psql -U "${PGUSER:-postgres}" -d "${PGDATABASE:-${POSTGRES_DB:-postgres}}" -tAXq|g' /usr/local/bin/pgbackrest-backup-watcher.sh
COPY --chmod=644 postgres/db/init.sql /docker-entrypoint-initdb.d/init.sql

ENTRYPOINT ["wrapper.sh"]
CMD ["postgres", "--port=5432"]

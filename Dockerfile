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

ENTRYPOINT ["wrapper.sh"]
CMD ["postgres", "--port=5432"]

# Use the Railway Postgres SSL image as base
FROM ghcr.io/railwayapp-templates/postgres-ssl:latest

RUN apt-get update && \
    apt-get install -y postgresql-${PG_MAJOR}-pgvector && \
    rm -rf /var/lib/apt/lists/*

# Copy the initialization script to modify pg_hba.conf
COPY postgres/db/init-hba.sh /docker-entrypoint-initdb.d/init-hba.sh
RUN chmod +x /docker-entrypoint-initdb.d/init-hba.sh

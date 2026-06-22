# Use the Railway Postgres SSL image as base
FROM ghcr.io/railwayapp-templates/postgres-ssl:latest

RUN apt-get update && \
    apt-get install -y postgresql-${PG_MAJOR}-pgvector && \
    rm -rf /var/lib/apt/lists/*

# Copy the initialization script to automatically enable vector extension
COPY postgres/db/init.sql /docker-entrypoint-initdb.d/init.sql

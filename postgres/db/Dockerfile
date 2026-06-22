# Use the Railway Postgres SSL image as base
FROM ghcr.io/railwayapp-templates/postgres-ssl:latest

RUN apt-get update && \
    apt-get install -y postgresql-${PG_MAJOR}-pgvector && \
    rm -rf /var/lib/apt/lists/*

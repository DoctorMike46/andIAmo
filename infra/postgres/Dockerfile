FROM postgis/postgis:16-3.4

# Add pgvector on top of PostGIS. The base image already has the PGDG apt repo
# configured, so we can install pgvector directly.
RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-16-pgvector \
    && rm -rf /var/lib/apt/lists/*

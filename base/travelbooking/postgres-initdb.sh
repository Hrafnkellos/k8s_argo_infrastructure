#!/bin/bash
# Runs once, on first start with an empty volume: Keycloak gets its own database.
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-SQL
  CREATE DATABASE keycloak OWNER $POSTGRES_USER;
SQL

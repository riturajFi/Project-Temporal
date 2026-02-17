#!/usr/bin/env bash
# Stop immediately if any command fails (`-e`), if unset vars are used (`-u`),
# and if any pipeline command fails (`-o pipefail`).
set -euo pipefail

# Read app DB name from env var, fallback to `app` if missing.
APP_DB_NAME="${APP_DB_NAME:-app}"

# Execute SQL against the bootstrap database using the configured Postgres user.
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" --set app_db="${APP_DB_NAME}" <<-'EOSQL'
-- Build and execute `CREATE DATABASE <name>` only if it does not already exist.
SELECT format('CREATE DATABASE %I', :'app_db')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'app_db')\gexec
EOSQL

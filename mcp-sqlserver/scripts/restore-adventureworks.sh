#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-mcp-sqlserver-demo}"
DB_NAME="${DB_NAME:-AdventureWorks2022}"
BACKUP_DIR_HOST="${BACKUP_DIR_HOST:-./backups}"
BACKUP_PATH_HOST="${BACKUP_PATH_HOST:-${BACKUP_DIR_HOST}/AdventureWorks2022.bak}"
BACKUP_PATH_CONTAINER="/var/opt/mssql/backup/AdventureWorks2022.bak"

AW2022_BAK_URL="https://github.com/microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2022.bak"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not installed." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required but not installed." >&2
  exit 1
fi

if [[ -z "${MSSQL_SA_PASSWORD:-}" ]]; then
  echo "MSSQL_SA_PASSWORD is not set. Source .env first (set -a; source .env; set +a)." >&2
  exit 1
fi

mkdir -p "${BACKUP_DIR_HOST}"

if [[ ! -f "${BACKUP_PATH_HOST}" ]]; then
  echo "Downloading AdventureWorks backup from GitHub releases..."
  curl -fL "${AW2022_BAK_URL}" -o "${BACKUP_PATH_HOST}"
fi

if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "Container ${CONTAINER_NAME} is not running. Start it first with docker compose up -d." >&2
  exit 1
fi

echo "Waiting for SQL Server to accept connections..."
for _ in {1..60}; do
  if docker exec "${CONTAINER_NAME}" /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P "${MSSQL_SA_PASSWORD:-}" -C -Q "SELECT 1" -b >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "Restoring ${DB_NAME} from ${BACKUP_PATH_CONTAINER}..."
docker exec "${CONTAINER_NAME}" /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "${MSSQL_SA_PASSWORD:-}" -C -b -Q "
IF DB_ID('${DB_NAME}') IS NOT NULL
BEGIN
  ALTER DATABASE [${DB_NAME}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
END;
RESTORE DATABASE [${DB_NAME}]
FROM DISK = N'${BACKUP_PATH_CONTAINER}'
WITH
  MOVE N'AdventureWorks2022' TO N'/var/opt/mssql/data/AdventureWorks2022.mdf',
  MOVE N'AdventureWorks2022_log' TO N'/var/opt/mssql/data/AdventureWorks2022_log.ldf',
  REPLACE,
  STATS=5;
ALTER DATABASE [${DB_NAME}] SET MULTI_USER;
"

echo "Restore complete. Verifying tables..."
docker exec "${CONTAINER_NAME}" /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "${MSSQL_SA_PASSWORD:-}" -C -Q "
SELECT TOP 5 TABLE_SCHEMA, TABLE_NAME
FROM [${DB_NAME}].INFORMATION_SCHEMA.TABLES
ORDER BY TABLE_SCHEMA, TABLE_NAME;
"

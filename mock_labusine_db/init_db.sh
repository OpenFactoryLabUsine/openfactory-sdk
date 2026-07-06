#!/usr/bin/env bash
set -euo pipefail

# 1. Start SQL Server in the background
/opt/mssql/bin/sqlservr &
SQL_PID=$!

# 2. Wait for SQL Server to be ready
echo "Waiting for SQL Server to boot..."
ready=0
for _ in $(seq 1 60); do
    if /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "SELECT 1" >/dev/null 2>&1; then
        echo "SQL Server is ready!"
        ready=1
        break
    fi
    sleep 1
done

if [ "$ready" -ne 1 ]; then
    echo "SQL Server did not become ready within the expected time. Aborting initialization."
    exit 1
fi

# 3. Create database and insert data
echo "Creating $MSSQL_DB_NAME and inserting equipment data..."
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "IF DB_ID(N'$MSSQL_DB_NAME') IS NULL CREATE DATABASE [$MSSQL_DB_NAME];"

for f in /tmp/sql-setup/sql-scripts/*.sql; do
    echo "Executing $f..."
    /opt/mssql-tools18/bin/sqlcmd -b -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -d "$MSSQL_DB_NAME" -i "$f"
done

# 4. Shut down SQL Server gracefully to save the data to the image layers
echo "Shutting down SQL Server to finalize image..."
kill $SQL_PID
wait $SQL_PID

echo "Database pre-baked successfully!"
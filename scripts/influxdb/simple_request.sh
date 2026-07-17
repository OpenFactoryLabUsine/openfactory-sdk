#!/bin/bash
INFLUX_URL="$1"
INFLUX_TOKEN="$2"
DB="$3"
SQL_QUERY="$4"

curl -s -X POST "$INFLUX_URL/api/v3/query_sql" \
  -H "Authorization: Bearer $INFLUX_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
      \"db\": \"$DB\",
      \"format\": \"jsonl\",
      \"q\": \"${SQL_QUERY//\"/\\\"}\"
    }"
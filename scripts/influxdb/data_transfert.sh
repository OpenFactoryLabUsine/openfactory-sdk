#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/pipeline.log"
INFLUX_URL="$1"
INFLUX_TOKEN="$2"
SOURCE_DB="$3"
TARGET_DB="$4"
SQL_QUERY="$5"
CHUNK_SIZE="$6"
TARGET_TABLE="$7"

curl -s -X POST "$INFLUX_URL/api/v3/query_sql" \
  -H "Authorization: Bearer $INFLUX_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
      \"db\": \"$SOURCE_DB\",
      \"format\": \"jsonl\",
      \"q\": \"${SQL_QUERY//\"/\\\"}\"
    }" | jq -r '
    ' | jq -r --arg target "$TARGET_TABLE" '
      "\($target),AssetUuid=\(.AssetUuid),Id=\(.Id),Tag=\(.Tag),Type=\(.Type) Value=\"\(.Value)\",CreatedAt=\"\(.CreatedAt)\" \(.epoch_ns)"
    ' | split -l "$CHUNK_SIZE" --filter="curl -s -X POST '$INFLUX_URL/api/v3/write_lp?db=$TARGET_DB&precision=ns' -H 'Authorization: Bearer $INFLUX_TOKEN' -H 'Content-Type: text/plain; charset=utf-8' --data-binary @-"

if [ ${PIPESTATUS[1]} -eq 0 ]; then
    echo "[v] Transfert réussi !" | tee -a "$LOG_FILE"
fi
#!/bin/bash

# ==========================================
# CONFIGURATION
# ==========================================
INFLUX_URL="http://172.19.0.7:8181"
TOKEN="apiv3_IpAIoj59qRM7alo6ULE66SG1iO0tuJsCLOAjBOyoyIbqZPQpCLLbKmDAB6PVH0EsRC1GX6J9uqGzw1DzGupHBA"
SOURCE_DB="ephemeral"
TARGET_DB="lifetime"

START_TIME="2026-06-26T01:47:00.008Z"
END_TIME="2026-07-01T20:47:00.008Z"

CHUNK_SIZE=20000
START_TS=$(date +%s)

echo "=== RUN ==="
echo "------------------------------------------------------"

SQL_QUERY="SELECT CAST(arrow_cast(time, 'Int64') AS VARCHAR) AS epoch_ns, \"ASSET_UUID\", \"ID\", \"TAG\", \"TYPE\", CAST(\"VALUE\" AS VARCHAR) AS \"VALUE\", CAST(\"TIMESTAMP\" AS VARCHAR) AS \"TIMESTAMP\" FROM only_cnc_data WHERE \"TAG\" NOT IN ('Application.License', 'Method', 'Method.Command', 'Library.License') AND \"TIMESTAMP\" >= '$START_TIME' AND \"TIMESTAMP\" <= '$END_TIME'"

curl -s -X POST "$INFLUX_URL/api/v3/query_sql" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
      \"db\": \"$SOURCE_DB\",
      \"format\": \"jsonl\",
      \"q\": \"${SQL_QUERY//\"/\\\"}\"
    }" | jq -r '
      "cnc_data,ASSET_UUID=\(.ASSET_UUID),ID=\(.ID),TAG=\(.TAG),TYPE=\(.TYPE) VALUE=\"\(.VALUE)\",TIMESTAMP=\"\(.TIMESTAMP)\" \(.epoch_ns)"
    ' | split -l $CHUNK_SIZE --filter="curl -s -X POST '$INFLUX_URL/api/v3/write_lp?db=$TARGET_DB&precision=ns' -H 'Authorization: Bearer $TOKEN' -H 'Content-Type: text/plain; charset=utf-8' --data-binary @-"


if [ ${PIPESTATUS[1]} -eq 0 ]; then
    echo -e "\n[!] Transfert réussi !"
else
    echo -e "\n[-] Le pipeline s'est arrêté prématurément."
fi

END_TS=$(date +%s)
ELAPSED_SECONDS=$((END_TS - START_TS))
printf '[⏱] Temps écoulé : %02d:%02d:%02d\n' $((ELAPSED_SECONDS / 3600)) $(((ELAPSED_SECONDS % 3600) / 60)) $((ELAPSED_SECONDS % 60))
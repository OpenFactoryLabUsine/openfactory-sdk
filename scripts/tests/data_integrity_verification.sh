#!/bin/bash


INFLUX_URL="http://172.19.0.6:8181"
TOKEN="apiv3_HbqdVR_YApDUOYcvIt1e8oFkk3096joxjZcxjHg3etS-u-ktI0_7ia0Kw6bJ0YACi-Q0c0HXMYQZHG2R1wHGJQ"
LIFETIME_DB="lifetime"
EPHEMERAL_DB="ephemeral"

START_TIME="2026-06-01T18:47:00.008Z"
END_TIME="2026-06-25T18:47:00.008Z"

CHUNK_SIZE=20000
START_TS=$(date +%s)

# On get le dernier time écrit dans la DB lifetime
echo "=== 1 QUERY dans la db lifetime ==="
SQL_QUERY="SELECT CAST(arrow_cast(time, 'Int64') AS VARCHAR) AS epoch_ns, CAST(\"TIMESTAMP\" AS VARCHAR) AS \"TIMESTAMP\" FROM cnc_data WHERE time >= '$START_TIME' AND time < '$END_TIME' ORDER BY time DESC LIMIT 1"

RESPONSE=$(curl -s -X POST "$INFLUX_URL/api/v3/query_sql" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
      \"db\": \"$LIFETIME_DB\",
      \"format\": \"jsonl\",
      \"q\": \"${SQL_QUERY//\"/\\\"}\"
    }")

LAST_TIME=$(echo "$RESPONSE" | jq -r '.epoch_ns') # time = moment où la période a été écrite dans la DB
LAST_TIMESTAMP=$(echo "$RESPONSE" | jq -r '.TIMESTAMP') # timestamp = moment où la période a été générée 


# On compte le nombre de données manquantes dans la DB lifetime en comparant avec la DB ephemeral
echo "=== 2 QUERY dans la DB ephemeral ==="
SECOND_SQL_QUERY="SELECT COUNT(\"ID\") FROM cnc_data WHERE \"TIMESTAMP\" < '$END_TIME' AND time > arrow_cast($LAST_TIME, 'Timestamp(Nanosecond, None)')"

RESPONSE=$(curl -s -X POST "$INFLUX_URL/api/v3/query_sql" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
      \"db\": \"$EPHEMERAL_DB\",
      \"format\": \"jsonl\",
      \"q\": \"${SECOND_SQL_QUERY//\"/\\\"}\"
    }")

REMAINING_COUNT=$(echo "$RESPONSE" | jq -r '."count(cnc_data.ID)"')

if [ "$REMAINING_COUNT" = "0" ]; then
    echo "Aucune donnée manquante dans la DB lifetime, arrêt du script."
    exit 0
else 
    echo "[!] $REMAINING_COUNT données manquantes dans la DB lifetime, lancement du script de transfert."
fi

# On récupère les données manquantes dans la DB ephemeral et on les écrit dans la DB lifetime
echo "=== 3 QUERY dans la DB ephemeral et lifetime ==="
SECOND_SQL_QUERY="SELECT CAST(arrow_cast(time, 'Int64') AS VARCHAR) AS epoch_ns, \"ASSET_UUID\", \"ID\", \"TAG\", \"TYPE\", CAST(\"VALUE\" AS VARCHAR) AS \"VALUE\", CAST(\"TIMESTAMP\" AS VARCHAR) AS \"TIMESTAMP\" FROM cnc_data WHERE \"TIMESTAMP\" < '$END_TIME' AND time >= arrow_cast($LAST_TIME, 'Timestamp(Nanosecond, None)')"

curl -s -X POST "$INFLUX_URL/api/v3/query_sql" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
      \"db\": \"$EPHEMERAL_DB\",
      \"format\": \"jsonl\",
      \"q\": \"${SECOND_SQL_QUERY//\"/\\\"}\"
    }"| jq -r '
      "cnc_data,ASSET_UUID=\(.ASSET_UUID),ID=\(.ID),TAG=\(.TAG),TYPE=\(.TYPE) VALUE=\"\(.VALUE)\",TIMESTAMP=\"\(.TIMESTAMP)\" \(.epoch_ns)"
    ' | split -l $CHUNK_SIZE --filter="curl -s -X POST '$INFLUX_URL/api/v3/write_lp?db=$LIFETIME_DB&precision=ns' -H 'Authorization: Bearer $TOKEN' -H 'Content-Type: text/plain; charset=utf-8' --data-binary @-"



END_TS=$(date +%s)
ELAPSED_SECONDS=$((END_TS - START_TS))
printf '[⏱] Temps écoulé : %02d:%02d:%02d\n' $((ELAPSED_SECONDS / 3600)) $(((ELAPSED_SECONDS % 3600) / 60)) $((ELAPSED_SECONDS % 60))
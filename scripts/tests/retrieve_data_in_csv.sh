#!/bin/bash


INFLUX_URL="http://172.19.0.6:8181"
TOKEN="apiv3_ZqO18RWxBTewhtTfq1Y5r-zCOKoTK8W0ZV-UN3WKk9HuwIE0-irpMXobfwprGEF_fh5fYQXgWmP7pXBKyt_sBA"
SOURCE_DB="lifetime"


INFLUXDB_COMPOSE_FILE="/usr/local/share/openfactory-sdk/openfactory-infra/docker-compose.influxdb.yml"

# Plages horaires au format ISO-8601 (UTC)
START_TIME="2026-06-01T18:47:00.008Z"
END_TIME="2026-06-22T18:47:00.008Z"

SQL_QUERY="SELECT time, \"ASSET_UUID\", \"ID\", \"TAG\", \"TYPE\", CAST(\"VALUE\" AS VARCHAR) AS \"VALUE\" FROM cnc_data WHERE time >= '$START_TIME' AND time < '$END_TIME' ORDER BY time DESC"

# Fichiers temporaires
touch /tmp/$SOURCE_DB.csv
RAW_RESPONSE="/tmp/{$SOURCE_DB}.csv"

echo "[...] Extraction des données depuis '$SOURCE_DB'..."

RESPONSE_INFO=$(curl -s -w "%{http_code}" -X POST "$INFLUX_URL/api/v3/query_sql" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: text/csv" \
  -d "{
    \"db\": \"$SOURCE_DB\",
    \"format\": \"csv\",
    \"q\": \"${SQL_QUERY//\"/\\\"}\"
  }" -o "$RAW_RESPONSE")

if [ "$RESPONSE_INFO" != "200" ]; then
    echo -e "\n[-] ERREUR LORS DE LA LECTURE (Code HTTP: $RESPONSE_INFO) :"
    cat "$RAW_RESPONSE"
    rm -f "$RAW_RESPONSE"
    exit 1
fi

echo "[...] stockage dans le path /tmp/influx_raw.csv"

tail -n +2 $RAW_RESPONSE | sort > /tmp/${SOURCE_DB}_trie.csv


# docker compose -f "$INFLUXDB_COMPOSE_FILE" -p influxdb up telegraf


# rm -f "$RAW_RESPONSE"



#!/bin/bash

# ==========================================
# CONFIGURATION
# ==========================================
INFLUX_URL="http://172.19.0.13:8181"
TOKEN="apiv3_HbqdVR_YApDUOYcvIt1e8oFkk3096joxjZcxjHg3etS-u-ktI0_7ia0Kw6bJ0YACi-Q0c0HXMYQZHG2R1wHGJQ"
SOURCE_DB="ephemeral"
TARGET_DB="lifetime"

START_TIME="2026-06-01T18:47:00.008Z"
END_TIME="2026-06-25T18:47:00.008Z"

CHUNK_SIZE=20000
START_TS=$(date +%s)

echo "=== RUN ==="
echo "------------------------------------------------------"

SQL_QUERY="SELECT \"time\", \"TIMESTAMP\", \"ASSET_UUID\", \"ID\", \"TAG\", \"TYPE\", CAST(\"VALUE\" AS VARCHAR) AS \"VALUE\" FROM cnc_data WHERE time >= '$START_TIME' AND time < '$END_TIME' ORDER BY time DESC"

curl -s -X POST "$INFLUX_URL/api/v3/query_sql" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"db\": \"$SOURCE_DB\",
    \"format\": \"json_lines\",
    \"q\": \"${SQL_QUERY//\"/\\\"}\"
  }" | jq -r '
    .time as $raw_time |
    
    # 1. On sépare la partie "secondes" de la partie "sous-secondes"
    ($raw_time | split(".")[0]) as $base_time |
    
    # 2. On force le "Z" sur la base pour que fromdateiso8601 l''accepte
    (($base_time + "Z" | fromdateiso8601) | tostring) as $sec |
    
    # 3. On extrait proprement les sous-secondes (jusqu aux nanosecondes)
    ((if ($raw_time | contains(".")) then ($raw_time | split(".")[1] | split("Z")[0]) else "000000000" end) | . + "000000000" | .[0:9]) as $nano |
    
    # 4. Génération de la ligne d''écriture
    "cnc_data,ASSET_UUID=\(.ASSET_UUID),ID=\(.ID),TAG=\(.TAG),TYPE=\(.TYPE) VALUE=\"\(.VALUE)\" \($sec)\($nano)"
  ' | split -l $CHUNK_SIZE --filter="curl -s -X POST '$INFLUX_URL/api/v3/write_lp?db=$TARGET_DB&precision=ns' -H 'Authorization: Bearer $TOKEN' -H 'Content-Type: text/plain; charset=utf-8' --data-binary @-"

if [ ${PIPESTATUS[1]} -eq 0 ]; then
    echo -e "\n[!] Transfert réussi"
else
    echo -e "\n[-] Bug."
fi

END_TS=$(date +%s)
ELAPSED_SECONDS=$((END_TS - START_TS))
printf '[⏱] Temps écoulé : %02d:%02d:%02d\n' $((ELAPSED_SECONDS / 3600)) $(((ELAPSED_SECONDS % 3600) / 60)) $((ELAPSED_SECONDS % 60))
#!/bin/bash

# ==========================================
# CONFIGURATION
# ==========================================
INFLUX_URL=""
TOKEN=""
SOURCE_DB="ephemeral"
TARGET_DB="ephemeral"

# Plages horaires au format ISO-8601 (UTC)
START_TIME="2026-06-01T18:47:00.008Z"
END_TIME="2026-06-29T18:47:00.008Z"

# Taille des paquets pour l'écriture (nombre de lignes par envoi HTTP)
CHUNK_SIZE=20000

SQL_QUERY="SELECT time, \"AssetUuid\", \"Id\", \"Tag\", \"Type\", \"Value\", \"CreatedAt\" FROM \"AssetsMetrics\" WHERE \"ASSET_UUID\" = 'DUSTTRAK' AND time >= '$START_TIME' AND time < '$END_TIME'"

# Fichiers temporaires
touch /tmp/influx_write_response.txt
RAW_RESPONSE="/tmp/influx_raw.csv"
PAYLOAD_FILE="/tmp/influx_payload.lp"
CHUNK_PREFIX="/tmp/influx_chunk_"
WRITE_RESPONSE="/tmp/influx_write_response.txt"

# Nettoyage initial
rm -f "$RAW_RESPONSE" "$PAYLOAD_FILE" "${CHUNK_PREFIX}"*

# ==========================================
# STEP 1 : EXTRACTION DU FLUX
# ==========================================
echo "[...] Extraction des données depuis '$SOURCE_DB'..."

RESPONSE_INFO=$(curl -s -w "%{http_code}" -X POST "$INFLUX_URL/api/v3/query_sql" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
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


# ==========================================
# STEP 2 : CONVERSION VIA AWK + OFFSET MS DYNAMIQUE
# ==========================================
echo "[...] Conversion du flux vers Line Protocol (Moteur Python)..."

python3 -c '
import csv, sys, time, re
from datetime import datetime

offset_step = 1
added_ms = 0

with open("'"$RAW_RESPONSE"'", "r", encoding="utf-8") as infile, open("'"$PAYLOAD_FILE"'", "w", encoding="utf-8") as outfile:
    reader = csv.reader(infile)
    next(reader)  # Skip header
    
    for row in reader:
        if len(row) < 7 or not row[0]: continue
        
        time_str = row[0]
        added_ms += offset_step
        
        # Extraction basique des ms/ns
        if "." in time_str:
            base_time, fractional = time_str.split("Z")[0].split(".")
            ns_str = (fractional + "000000000")[:9]
        else:
            base_time = time_str.split("Z")[0]
            ns_str = "000000000"
            
        # Conversion du temps ISO en epoch (Python 3.7+)
        epoch_sec = int(datetime.fromisoformat(base_time.replace("Z", "")).timestamp())
        
        # Calcul final du timestamp en nanosecondes
        timestamp_ns = (epoch_sec * 1000000000) + int(ns_str) + (added_ms * 1000000)
        
        # Nettoyage de la valeur (enlève les sauts de ligne qui cassent le Line Protocol)
        val = row[5].replace("\n", "").replace("\r", "")
        # Echappement des guillemets pour le Line Protocol InfluxDB
        val = val.replace("\"", "\\\"")
        
        # Formatage de la ligne
        lp_line = f"AssetsMetrics,AssetUuid={row[1]},Id={row[2]},Tag={row[3]},Type={row[4]} Value=\"{val}\",CreatedAt=\"{row[6]}\" {timestamp_ns}\n"
        outfile.write(lp_line)
'

LINE_COUNT=$(wc -l < "$PAYLOAD_FILE")
echo "[+] $LINE_COUNT lignes prêtes pour l'injection."

# ==========================================
# STEP 3 : DÉCOUPAGE ET INJECTION PAR CHUNKS
# ==========================================
echo "[...] Découpage du fichier en paquets de $CHUNK_SIZE lignes..."
split -l "$CHUNK_SIZE" "$PAYLOAD_FILE" "$CHUNK_PREFIX"

TOTAL_CHUNKS=$(ls "${CHUNK_PREFIX}"* | wc -l)
CURRENT_CHUNK=1

echo "[...] Écriture séquentielle vers la base cible '$TARGET_DB' ($TOTAL_CHUNKS paquets)..."

for chunk in "${CHUNK_PREFIX}"*; do
    echo -n "    -> Envoi du paquet $CURRENT_CHUNK/$TOTAL_CHUNKS... "
    
    WRITE_CODE=$(curl -s -o "$WRITE_RESPONSE" -w "%{http_code}" -X POST "$INFLUX_URL/api/v3/write_lp?db=$TARGET_DB" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: text/plain; charset=utf-8" \
      --data-binary @"$chunk")

    if [ "$WRITE_CODE" == "204" ] || [ "$WRITE_CODE" == "200" ]; then
        echo "OK (Code $WRITE_CODE)"
    else
        echo -e "\n[-] Erreur lors de l'écriture du paquet $CURRENT_CHUNK. Code HTTP : $WRITE_CODE"
        cat "$WRITE_RESPONSE"
        rm -f "$RAW_RESPONSE" "$PAYLOAD_FILE" "${CHUNK_PREFIX}"* "$WRITE_RESPONSE"
        exit 1
    fi
    CURRENT_CHUNK=$((CURRENT_CHUNK + 1))
done

echo "[🎉] Succès global ! Transfert de $LINE_COUNT lignes vers '$TARGET_DB' terminé."

# Nettoyage final
rm -f "$RAW_RESPONSE" "$PAYLOAD_FILE" "${CHUNK_PREFIX}"*
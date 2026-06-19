#!/bin/bash

# ==========================================
# CONFIGURATION
# ==========================================
INFLUX_URL="http://172.19.0.6:8181"
TOKEN="apiv3_ZqO18RWxBTewhtTfq1Y5r-zCOKoTK8W0ZV-UN3WKk9HuwIE0-irpMXobfwprGEF_fh5fYQXgWmP7pXBKyt_sBA"
SOURCE_DB="ephemeral"
TARGET_DB="ephemeral"

# Plages horaires au format ISO-8601 (UTC)
START_TIME="2026-06-01T18:47:00.008Z"
END_TIME="2026-06-22T18:47:00.008Z"

# Taille des paquets pour l'écriture (nombre de lignes par envoi HTTP)
CHUNK_SIZE=20000

# ==========================================
# MENU INTERACTIF
# ==========================================
echo "=== PIPELINE OPTIMISÉ INFLUXDB 3 ==="
echo "Période : $START_TIME à $END_TIME"
echo "----------------------------------------"
echo "1) Mode Haute Fréquence : Tout transférer"
echo "2) Mode Standard        : Downsampling (1 donnée / 10s)"
echo "----------------------------------------"
read -p "Entrez votre choix (1 ou 2) : " CHOIX

if [ "$CHOIX" == "1" ]; then
    echo -e "\n[⚡] Préparation du flux COMPLET..."
    SQL_QUERY="SELECT time, \"ASSET_UUID\", \"ID\", \"TAG\", \"TYPE\", \"VALUE\" FROM cnc_data WHERE time >= '$START_TIME' AND time < '$END_TIME'"
fi

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
echo "[...] Conversion du flux vers Line Protocol (Moteur awk)..."

awk -F, -v offset_step="1" '
NR==1 { next } 
{
    gsub(/\r|\n/, "", $6) 
    if ($1 == "") next
    
    # 1. Extraction du temps de base
    year  = substr($1, 1, 4)
    month = substr($1, 6, 2)
    day   = substr($1, 9, 2)
    hour  = substr($1, 12, 2)
    min   = substr($1, 15, 2)
    sec   = substr($1, 18, 2)
    
    epoch_sec = mktime(year " " month " " day " " hour " " min " " sec)
    if (epoch_sec <= 0) next
    
    # 2. Extraction des nanosecondes d origine (.074029619)
    dot_pos = index($1, ".")
    if (dot_pos > 0) {
        ns_str = substr($1, dot_pos + 1)
        gsub(/[^0-9]/, "", ns_str)
    } else {
        ns_str = "000000000"
    }
    while (length(ns_str) < 9) ns_str = ns_str "0"
    ns_str = substr(ns_str, 1, 9)

    # 3. CONVERSION EN VALEUR NUMÉRIQUE ET AJOUT DE L OFFSET
    # NR est le numéro de la ligne actuelle. On ajoute (NR * offset_step) en millisecondes
    # 1 milliseconde = 1 000 000 nanosecondes
    added_ns = NR * offset_step * 1000000
    
    # On rassemble les secondes et les nanosecondes en un gros chiffre mathématique
    # puis on ajoute l offset de ms converti en nanosecondes
    timestamp_ns = (epoch_sec * 1000000000) + ns_str + added_ns
    
    # Génération de la ligne Line Protocol
    printf "cnc_data,ASSET_UUID=%s,ID=%s,TAG=%s,TYPE=%s VALUE=\"%s\" %.0f\n", $2, $3, $4, $5, $6, timestamp_ns
}' "$RAW_RESPONSE" > "$PAYLOAD_FILE"

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
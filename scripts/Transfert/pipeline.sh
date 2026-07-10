#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Configuration
INFLUX_URL="${1:-"http://172.19.0.7:8181"}"
INFLUX_TOKEN="${2:-"apiv3_cEcxV41p9h_Rrk2liaZygK92N3WeeljXRPtQ4MUUMpIdpXKW3KS93hCuBE7geHA3nKuLqCbo3na9dRvZ02i1GQ"}"
SOURCE_DB="${3:-"ephemeral"}"
TARGET_DB="${4:-"test"}"
SOURCE_TABLE="${5:-"cnc_data"}"
TARGET_TABLE="${6:-"prod_data"}"
WANTED_ASSET_UUID="${7:-"DEV-UUID"}"
BUFFER_TIME="${8:-"10"}"
START_TIME_LOCAL="${9:-"2026-06-26T13:15:17"}"
END_TIME_LOCAL="${10:-"2026-07-09T20:50:00"}"
TIMEZONE="${11:-"America/Toronto"}"
VARIABLE_RECORDING_ID="${12:-"2"}"
MPS="${13:-"1"}"
VARIABLE_ID="${14:-"1"}"
CHUNK_SIZE=20000
START_TS=$(date +%s)
# Configuration UNS
DB_SERVER="host.docker.internal"
DB_NAME="labusine_db"
DB_USER="bash"
DB_PASS="password"

# Variables qui vont être mises à jour
LAST_TIME=""
POLL_INTERVAL=""
END_BUFFER_TIME_LOCAL=""
# Variables pour l'UNS
STATUT="InProgress"
TRANSFERT_START_TIME_UTC=$(date -u +"%Y-%m-%d %H:%M:%S")
TRANSFERT_END_TIME_UTC=""
DURATION=""
TOTAL_NUMBER_LINES_TRANSFERRED=0
BUFFER_NUMBER_LINES_TRANSFERRED=0
SQL_ERR_MSG="NULL"

# Fonction pour exécuter une requête SQL sur la base de données UNS
update_uns() {
    local SQL_QUERY="$1"
    # Nécessite le paquet mssql-tools
    sqlcmd -S "$DB_SERVER" -d "$DB_NAME" -U "$DB_USER" -P "$DB_PASS" -C -Q "$SQL_QUERY" > /dev/null
    return $?
}

# Fonction de gestion des erreurs
handle_error() {
local msg="$1"
    echo -e "\n[ERREUR] $msg" >&2
    STATUT="Failed"
    SQL_ERR_MSG="'${msg//\'/\'\'}'" # Escape des single quotes pour SQL et emballage
    TRANSFERT_END_TIME_UTC=$(date -u +"%Y-%m-%d %H:%M:%S")
    DURATION=$(( $(date +%s) - START_TS ))
    update_uns "UPDATE VariableRecordingRequest SET Statut = 'Failed' WHERE id = '${VARIABLE_RECORDING_ID}';"
    local eq_id="${EQUIPMENT_ID:-NULL}"
    update_uns "INSERT INTO VariableRecordingLogs (VariableRecoringId, EquipmentId, TransfertStartTime, TransfertEndTime, Duration, TotalNumberLinesTransfered, NumberLinesTransferedDuringBuffer, ErrorMessage) VALUES ('${VARIABLE_RECORDING_ID}', '${eq_id}', '${TRANSFERT_START_TIME_UTC}', '${TRANSFERT_END_TIME_UTC}', '${DURATION}', ${TOTAL_NUMBER_LINES_TRANSFERRED}, ${BUFFER_NUMBER_LINES_TRANSFERRED}, ${SQL_ERR_MSG});"
    exit 1
}

# 0) Mettre à jour le Statut dans l'UNS vers InProgress
update_uns "UPDATE VariableRecordingRequest SET Statut = 'InProgress' WHERE id = '$VARIABLE_RECORDING_ID';"
if [ $? -ne 0 ]; then
    echo "[x] Impossible de joindre SQL Server pour Modifier le statut à InProgress." >&2
    exit 1
fi

# Récupérer l'id de l'équipement associé à la variable lors de l'enregistrement
EQUIPMENT_ID=$(sqlcmd -S "$DB_SERVER" -d "$DB_NAME" -U "$DB_USER" -P "$DB_PASS" -C -h -1 -W -Q "SET NOCOUNT ON; SELECT EquipmentId FROM Variable WHERE id = '$VARIABLE_ID';")
if [ $? -ne 0 ]; then
    echo "[x] Impossible de joindre SQL Server pour récupérer EquipmentId." >&2
    exit 1
fi

echo "EquipmentID : ${EQUIPMENT_ID}"

# Convertir les heures locales en UTC pour la requête SQL
EPOCH_START=$(TZ="$TIMEZONE" date -d "${START_TIME_LOCAL/T/ }" +"%s")
EPOCH_END=$(TZ="$TIMEZONE" date -d "${END_TIME_LOCAL/T/ }" +"%s")
START_TIME_UTC=$(date -u -d "@$EPOCH_START" +"%Y-%m-%dT%H:%M:%SZ")
END_TIME_UTC=$(date -u -d "@$EPOCH_END" +"%Y-%m-%dT%H:%M:%SZ")

echo -e "\nDébut du script à $(TZ="$TIMEZONE" date "+%H:%M:%S") heure locale ($TIMEZONE) pour l'ASSET_UUID : $WANTED_ASSET_UUID, période de transfert de $START_TIME_UTC UTC à $END_TIME_UTC UTC."

# 1) Nombre de lignes à transférer
SQL_QUERY="SELECT COUNT(\"ASSET_UUID\") AS total_count FROM $SOURCE_TABLE WHERE \"ASSET_UUID\" = '$WANTED_ASSET_UUID' AND \"TAG\" NOT IN ('Application.License', 'Method', 'Method.Command', 'Library.License') AND \"TIMESTAMP\" >= '$START_TIME_UTC' AND \"TIMESTAMP\" <= '$END_TIME_UTC'"
RESPONSE=$("$SCRIPT_DIR/simple_request.sh" "$INFLUX_URL" "$INFLUX_TOKEN" "$SOURCE_DB" "$SQL_QUERY")
if [ $? -ne 0 ]; then
    handle_error "[x] Échec de connexion ou d'exécution de simple_request.sh (Source: $SOURCE_DB)."
else
TOTAL_NUMBER_LINES_TRANSFERRED=$(echo "$RESPONSE" | jq -r '.total_count // 0')
fi

# 2) Transfert des données de la DB SOURCE vers la DB TARGET
echo -e "\n[~] Lancement du transfert de $TOTAL_NUMBER_LINES_TRANSFERRED lignes de la DB $SOURCE_DB vers la DB $TARGET_DB pour l'ASSET_UUID : $WANTED_ASSET_UUID."
SQL_QUERY="SELECT CAST(arrow_cast(time, 'Int64') AS VARCHAR) AS epoch_ns, \"ASSET_UUID\", \"ID\", \"TAG\", \"TYPE\", CAST(\"VALUE\" AS VARCHAR) AS \"VALUE\", CAST(\"TIMESTAMP\" AS VARCHAR) AS \"TIMESTAMP\" FROM $SOURCE_TABLE WHERE \"ASSET_UUID\" = '$WANTED_ASSET_UUID' AND \"TAG\" NOT IN ('Application.License', 'Method', 'Method.Command', 'Library.License') AND \"TIMESTAMP\" >= '$START_TIME_UTC' AND \"TIMESTAMP\" <= '$END_TIME_UTC'"
"$SCRIPT_DIR/data_transfert.sh" "$INFLUX_URL" "$INFLUX_TOKEN" "$SOURCE_DB" "$TARGET_DB" "$SQL_QUERY" "$CHUNK_SIZE" "$TARGET_TABLE"
if [ $? -ne 0 ]; then
    handle_error "[x] Erreur lors du transfert des données (data_transfert.sh)."
fi

# 3) Récupération du dernier timestamp écrit dans la DB TARGET
SQL_QUERY="SELECT CAST(arrow_cast(time, 'Int64') AS VARCHAR) AS epoch_ns FROM $TARGET_TABLE WHERE \"TIMESTAMP\" >= '$START_TIME_UTC' AND \"TIMESTAMP\" <= '$END_TIME_UTC' ORDER BY time DESC LIMIT 1"
RESPONSE=$("$SCRIPT_DIR/simple_request.sh" "$INFLUX_URL" "$INFLUX_TOKEN" "$TARGET_DB" "$SQL_QUERY")
LAST_TIME=$(echo "$RESPONSE" | jq -r '.epoch_ns // empty')
# -z = vérifie si la variable est vide
if [ -z "$LAST_TIME" ]; then
    LAST_TIME=0
    handle_error "[x] Impossible de récupérer le dernier timestamp UTC de la DB $TARGET_DB"
fi
echo -e "\n[~] Timestamp en nanosecondes de la colonne "time" de la dernière donnée transférée dans la DB $TARGET_DB : $LAST_TIME"


# 4) Boucle de buffer pour vérifier les données manquantes
# Si le temps de buffer est inférieur ou égal à 60 secondes
if [ "$BUFFER_TIME" -le 60 ]; then
    POLL_INTERVAL=$BUFFER_TIME
else
    POLL_INTERVAL=$((BUFFER_TIME / 2))
fi

# Calcul du temps de fin de la période de buffer 
END_BUFFER_TIME_LOCAL=$(( $(date +%s) + BUFFER_TIME ))

echo -e "\n[~] Début de la période de buffer de ${BUFFER_TIME} secondes à $(TZ="$TIMEZONE" date "+%H:%M:%S") heure locale ($TIMEZONE). Fin prévue vers $(TZ="$TIMEZONE" date -d "@$END_BUFFER_TIME_LOCAL" '+%H:%M:%S') heure locale ($TIMEZONE)."

while [ $(date +%s) -lt $END_BUFFER_TIME_LOCAL ]; do
    sleep $POLL_INTERVAL
    # 4.1) Comptage du nombre de données manquantes
    # -gt vérifie si la variable est supérieure à 0
    if [ "$LAST_TIME" -gt 0 ]; then
        SQL_QUERY="SELECT COUNT(\"ASSET_UUID\") AS total_count FROM $SOURCE_TABLE WHERE \"ASSET_UUID\" = '$WANTED_ASSET_UUID' AND \"TIMESTAMP\" >= '$START_TIME_UTC' AND \"TIMESTAMP\" <= '$END_TIME_UTC' AND time > arrow_cast($LAST_TIME, 'Timestamp(Nanosecond, None)')"
        RESPONSE=$("$SCRIPT_DIR/simple_request.sh" "$INFLUX_URL" "$INFLUX_TOKEN" "$SOURCE_DB" "$SQL_QUERY")
        if [ $? -ne 0 ]; then
            handle_error "[x] Échec de connexion ou d'exécution de simple_request.sh (Source: $SOURCE_DB)."
        else
        REMAINING_COUNT=$(echo "$RESPONSE" | jq -r '.total_count // 0')
        BUFFER_NUMBER_LINES_TRANSFERRED=$((BUFFER_NUMBER_LINES_TRANSFERRED + REMAINING_COUNT))
        fi
    else
        REMAINING_COUNT=0
    fi

    if [ "$REMAINING_COUNT" = "0" ] || [ -z "$REMAINING_COUNT" ] || [ "$REMAINING_COUNT" = "null" ]; then
        echo -e "\n[~] Buffer : aucune nouvelle donnée manquante détectée."
    else
        echo "[!] Buffer : $REMAINING_COUNT nouvelles données manquantes détectées."
        
        # 4.2) Transfert des données manquantes
        SQL_QUERY="SELECT CAST(arrow_cast(time, 'Int64') AS VARCHAR) AS epoch_ns, \"ASSET_UUID\", \"ID\", \"TAG\", \"TYPE\", CAST(\"VALUE\" AS VARCHAR) AS \"VALUE\", CAST(\"TIMESTAMP\" AS VARCHAR) AS \"TIMESTAMP\" FROM $SOURCE_TABLE WHERE \"ASSET_UUID\" = '$WANTED_ASSET_UUID' AND \"TIMESTAMP\" >= '$START_TIME_UTC' AND \"TIMESTAMP\" <= '$END_TIME_UTC' AND time > arrow_cast($LAST_TIME, 'Timestamp(Nanosecond, None)')"
        "$SCRIPT_DIR/data_transfert.sh" "$INFLUX_URL" "$INFLUX_TOKEN" "$SOURCE_DB" "$TARGET_DB" "$SQL_QUERY" "$CHUNK_SIZE" "$TARGET_TABLE"
        if [ $? -ne 0 ]; then
            handle_error "[x] Erreur lors du transfert des données (data_transfert.sh)."
        fi
        # Mise à jour du pivot pour éviter de re-transférer les mêmes données à la prochaine itération
        SQL_QUERY="SELECT CAST(arrow_cast(time, 'Int64') AS VARCHAR) AS epoch_ns FROM $TARGET_TABLE WHERE \"TIMESTAMP\" >= '$START_TIME_UTC' AND \"TIMESTAMP\" <= '$END_TIME_UTC' ORDER BY time DESC LIMIT 1"
        RESPONSE=$("$SCRIPT_DIR/simple_request.sh" "$INFLUX_URL" "$INFLUX_TOKEN" "$TARGET_DB" "$SQL_QUERY")
        if [ $? -ne 0 ]; then
            handle_error "[x] Échec de connexion ou d'exécution de simple_request.sh (Source: $SOURCE_DB)."
        fi
        NEW_LAST_TIME=$(echo "$RESPONSE" | jq -r '.epoch_ns // empty')
        if [ -n "$NEW_LAST_TIME" ] && [ "$NEW_LAST_TIME" != "null" ]; then
            LAST_TIME=$NEW_LAST_TIME
            echo -e "[~] Timestamp en nanosecondes de la colonne time de la dernière donnée transférée dans la DB $TARGET_DB : $LAST_TIME \n"
        fi
    fi
done

if [ "$STATUT" != "Failed" ]; then
    STATUT="Processed"
fi

# Mettre à jour le Statut dans l'UNS vers Processed
update_uns "UPDATE VariableRecordingRequest SET Statut = 'Processed' WHERE Id = '$VARIABLE_RECORDING_ID';"
if [ $? -ne 0 ]; then
    echo "[x] Impossible de joindre SQL Server pour mettre à jour le statut vers Processed." >&2
    exit 1
fi

# Fin du script 
TOTAL_NUMBER_LINES_TRANSFERRED=$((TOTAL_NUMBER_LINES_TRANSFERRED + BUFFER_NUMBER_LINES_TRANSFERRED))
END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))
# Temps de fin du transfert en UTC
TRANSFERT_END_TIME_UTC=$(date -u +"%Y-%m-%d %H:%M:%S")
# Créer un enregistrement dans la table VariableRecordingLogs pour le transfert
update_uns "INSERT INTO VariableRecordingLogs (VariableRecoringId, EquipmentId, TransfertStartTime, TransfertEndTime, Duration, TotalNumberLinesTransfered, NumberLinesTransferedDuringBuffer, ErrorMessage) VALUES ('${VARIABLE_RECORDING_ID}', '${EQUIPMENT_ID}', '${TRANSFERT_START_TIME_UTC}', '${TRANSFERT_END_TIME_UTC}', '${DURATION}', ${TOTAL_NUMBER_LINES_TRANSFERRED}, ${BUFFER_NUMBER_LINES_TRANSFERRED}, ${SQL_ERR_MSG});"
if [ $? -ne 0 ]; then
    echo "[x] Impossible de joindre SQL Server pour créer un enregistrement dans VariableRecordingLogs." >&2
    exit 1
fi

printf '[*] Temps écoulé depuis le lancement du script: %02d:%02d:%02d\n' $((DURATION / 3600)) $(((DURATION % 3600) / 60)) $((DURATION % 60))
echo -e "\n[~] Script terminé. Statut = ${STATUT}, Transfert de ${TOTAL_NUMBER_LINES_TRANSFERRED} lignes dont ${BUFFER_NUMBER_LINES_TRANSFERRED} durant la période du buffer, Durée = ${DURATION} secondes, Début = $(TZ="$TIMEZONE" date -d "${TRANSFERT_START_TIME_UTC} UTC" +"%Y-%m-%d %H:%M:%S") heure locale ($TIMEZONE), Fin = $(TZ="$TIMEZONE" date -d "${TRANSFERT_END_TIME_UTC} UTC" +"%Y-%m-%d %H:%M:%S") heure locale ($TIMEZONE)."
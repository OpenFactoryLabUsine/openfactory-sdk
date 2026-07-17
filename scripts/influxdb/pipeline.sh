#!/bin/bash
# Configuration variables d'environnement
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/pipeline.log"
touch "$LOG_FILE"
echo -e "\n[~] $(date '+%Y-%m-%d %H:%M:%S') (UTC) - Début du script pipeline.sh" | tee -a "$LOG_FILE"
clear
ENV_FILE="$SCRIPT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "[x] Fichier .env introuvable. Veuillez créer un fichier .env à la racine du projet avec les variables d'environnement nécessaires." | tee -a "$LOG_FILE"
    exit 1
fi
# Configuration
INFLUX_URL=$INFLUX_URL
INFLUX_TOKEN=$INFLUX_TOKEN
SOURCE_DB=$SOURCE_DB
TARGET_DB=$TARGET_DB
SOURCE_TABLE=$SOURCE_TABLE
TARGET_TABLE=$TARGET_TABLE
CHUNK_SIZE=$CHUNK_SIZE
START_TS=$(date +%s)
VAR_CONDITION=""
UNWANTED_TAGS="('Application.License', 'Method', 'Method.Command', 'Library.License')"
# Configuration UNS
DB_SERVER=$DB_SERVER
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS
# Variables qui vont être mises à jour
LAST_TIME=""
END_BUFFER_TIME_LOCAL=""
# Variables pour l'UNS
STATUT="InProgress"
TRANSFERT_START_TIME_UTC=$(date -u +"%Y-%m-%dT%H:%M:%S")
TRANSFERT_END_TIME_UTC=""
DURATION=""
TOTAL_NUMBER_LINES_TRANSFERRED=0
BUFFER_NUMBER_LINES_TRANSFERRED=0
SQL_ERR_MSG="NULL"
VARIABLE_ID="NULL"
EQUIPMENT_ID="NULL"
# Paramètre
VARIABLE_RECORDING_REQUEST_ID="${1:-""}" # Obligatoire

if [ -z "$VARIABLE_RECORDING_REQUEST_ID" ]; then
    echo "[x] Vous devez fournir l'ID de la demande d'enregistrement de variable. Veuillez réessayer." | tee -a "$LOG_FILE"
    exit 1
fi

# Fonctions pour interagir avec l'UNS
dialog_with_uns() {
    local SQL_QUERY="$1"
    local SQL_ERR_MSG="$2"
    local GET_SPECIFIC_DATA="${3:-false}"
    if [ "$GET_SPECIFIC_DATA" = "true" ]; then
        local result=$(sqlcmd -S "$DB_SERVER" -d "$DB_NAME" -U "$DB_USER" -P "$DB_PASS" -C -b -h -1 -W -Q "$SQL_QUERY" 2>/dev/null)
        echo "$result"
    else 
        sqlcmd -S "$DB_SERVER" -d "$DB_NAME" -U "$DB_USER" -P "$DB_PASS" -C -b -Q "$SQL_QUERY" > /dev/null
    fi
    if [ $? -ne 0 ]; then
        handle_error "$SQL_ERR_MSG" "true"
    fi
}

# Fonction de gestion des erreurs
handle_error() {
    local msg="$1"
    local is_uns_connexion_error="${2:-"false"}"
    echo "[x] $msg" | tee -a "$LOG_FILE"
    STATUT="Failed"
    SQL_ERR_MSG="'${msg//\'/\'\'}'"
    TRANSFERT_END_TIME_UTC=$(date -u +"%Y-%m-%dT%H:%M:%S")
    DURATION=$(( $(date +%s) - START_TS ))
    local eq_id="${EQUIPMENT_ID:-NULL}"
    local var_id="${VARIABLE_ID:-NULL}"
    if [ "$is_uns_connexion_error" = "true" ]; then
        exit 1
    else
        dialog_with_uns "UPDATE VariableRecordingRequest SET Statut = 'Failed' WHERE id = '${VARIABLE_RECORDING_REQUEST_ID}';" ""
        dialog_with_uns "INSERT INTO VariableRecordingLogs (VariableRecoringId, EquipmentId, VariableId, TransfertStartTime, TransfertEndTime, Duration, TotalNumberLinesTransfered, NumberLinesTransferedDuringBuffer, ErrorMessage) VALUES ('${VARIABLE_RECORDING_REQUEST_ID}', ${eq_id}, ${var_id}, '${TRANSFERT_START_TIME_UTC}', '${TRANSFERT_END_TIME_UTC}', '${DURATION}', '${TOTAL_NUMBER_LINES_TRANSFERRED}', '${BUFFER_NUMBER_LINES_TRANSFERRED}', ${SQL_ERR_MSG});" ""
    fi
    exit 1
}

# Fonction pour récupérer les données de la demande d'enregistrement de variable depuis l'UNS
get_variable_recording_request_data() {
    local query="SET NOCOUNT ON; SELECT COALESCE(WantedVariableName, 'NULL_VALUE'), WantedAssetUuid, Statut, LocalStartTime, LocalEndTime, Mps, BufferTime, TimeZone FROM VariableRecordingRequest WHERE id = '$VARIABLE_RECORDING_REQUEST_ID';"
    data=$(sqlcmd -S "$DB_SERVER" -d "$DB_NAME" -U "$DB_USER" -P "$DB_PASS" -C -h -1 -W -s "|" -Q "$query" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$data" ]; then
        handle_error "Impossible de joindre SQL Server." "true"
    fi
    IFS='|' read -r WANTED_VARIABLE_NAME WANTED_ASSET_UUID STATUT LOCAL_START_TIME LOCAL_END_TIME MPS BUFFER_TIME TIMEZONE <<< "$data"

    # Récupérer l'id de l'équipement associé à la variable lors de l'enregistrement
    eq_id_response=$(dialog_with_uns "SET NOCOUNT ON; SELECT id FROM Equipment WHERE AssetUuid = '$WANTED_ASSET_UUID';" "Impossible de joindre SQL Server pour récupérer EquipmentId." "true")
    EQUIPMENT_ID="'$eq_id_response'"

    # Si un wanted_variable_name est spécifié, récupérer l'id de la variable associée à l'équipement lors de l'enregistrement
    if [ "$WANTED_VARIABLE_NAME" != 'NULL_VALUE' ]; then 
        RES_ID=$(dialog_with_uns "SET NOCOUNT ON; SELECT id FROM Variable WHERE EquipmentId = $EQUIPMENT_ID AND Nom = '$WANTED_VARIABLE_NAME';" "Impossible de joindre SQL Server pour récupérer VariableId." "true")
        VARIABLE_ID="'$RES_ID'"
    fi

    if [[ "$STATUT" = "Processed" || "$STATUT" = "InProgress" ]]; then
        handle_error "La demande d'enregistrement de variable avec l'ID $VARIABLE_RECORDING_REQUEST_ID n'est pas en statut 'Planned', impossible de lancer le script. Statut actuel : $STATUT."
    elif [[ -z "$LOCAL_END_TIME" ]]; then
        handle_error "La date de fin locale ne peut pas être vide. Veuillez vérifier l'entrée dans l'UNS."
    elif [[ "$LOCAL_END_TIME" < "$LOCAL_START_TIME" ]]; then
        handle_error "La date de fin locale est antérieure à la date de début locale. Veuillez vérifier les entrées dans l'UNS."
    elif ! [[ "$LOCAL_END_TIME" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] || ! [[ "$LOCAL_START_TIME" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
        handle_error "L'une des dates locales n'est pas au format attendu (YYYY-MM-DDTHH:MM:SS). Veuillez vérifier les entrées dans l'UNS."
    fi
}
get_variable_recording_request_data

# Fonction pour compter le nombre de lignes à transférer depuis la DB SOURCE vers la DB TARGET
count_number_lines(){
    local sql_query=$1
    RESPONSE_COUNT_DATA=$("$SCRIPT_DIR/simple_request.sh" "$INFLUX_URL" "$INFLUX_TOKEN" "$SOURCE_DB" "$sql_query")
    if [ $? -ne 0 ]; then
        handle_error "[x] Erreur d'une requête sur influxdb3 (script simple_request.sh)."
    fi
}

# Fonction pour transférer les données de la DB SOURCE vers la DB TARGET
transfert_data(){
    local sql_query=$1
    "$SCRIPT_DIR/data_transfert.sh" "$INFLUX_URL" "$INFLUX_TOKEN" "$SOURCE_DB" "$TARGET_DB" "$sql_query" "$CHUNK_SIZE" "$TARGET_TABLE"
    if [ $? -ne 0 ]; then
        handle_error "[x] Erreur lors du transfert des données (script data_transfert.sh)."
    fi
}

# Permet de modifier dynamiquement la condition des requêtes SQL
if [ "$WANTED_VARIABLE_NAME" != 'NULL_VALUE' ]; then
    VAR_CONDITION="AND \"Id\" = '$WANTED_VARIABLE_NAME'"
fi

# 1) Mettre à jour le Statut dans l'UNS vers InProgress
dialog_with_uns "UPDATE VariableRecordingRequest SET Statut = 'InProgress' WHERE id = '$VARIABLE_RECORDING_REQUEST_ID';" "Impossible de joindre SQL Server pour Modifier le statut à InProgress."

# 2) Convertir les heures locales récupérées de la VariableRecordingRequest en UTC pour la requête SQL
EPOCH_START=$(TZ="$TIMEZONE" date -d "${LOCAL_START_TIME/T/ }" +"%s")
EPOCH_END=$(TZ="$TIMEZONE" date -d "${LOCAL_END_TIME/T/ }" +"%s")
START_TIME_UTC=$(date -u -d "@$EPOCH_START" +"%Y-%m-%dT%H:%M:%SZ")
END_TIME_UTC=$(date -u -d "@$EPOCH_END" +"%Y-%m-%dT%H:%M:%SZ")

echo "[~] Début du script à $(TZ="$TIMEZONE" date "+%H:%M:%S") heure locale ($TIMEZONE) pour le VariableRecordingRequest ID : $VARIABLE_RECORDING_REQUEST_ID, l'AssetUuid : $WANTED_ASSET_UUID et le VariableName : $WANTED_VARIABLE_NAME, période de transfert de $START_TIME_UTC UTC à $END_TIME_UTC UTC." | tee -a "$LOG_FILE"

# 3) Compatage du nombre de lignes à transférer
count_number_lines "SELECT COUNT(\"AssetUuid\") AS total_count FROM \"$SOURCE_TABLE\" WHERE \"AssetUuid\" = '$WANTED_ASSET_UUID' $VAR_CONDITION AND \"Tag\" NOT IN $UNWANTED_TAGS AND \"CreatedAt\" >= '$START_TIME_UTC' AND \"CreatedAt\" <= '$END_TIME_UTC'"
TOTAL_NUMBER_LINES_TRANSFERRED=$(echo "$RESPONSE_COUNT_DATA" | jq -r '.total_count // 0')

# 4) Transfert des données de la DB SOURCE vers la DB TARGET
echo "[~] Lancement du transfert de $TOTAL_NUMBER_LINES_TRANSFERRED lignes de la DB $SOURCE_DB vers la DB $TARGET_DB pour l'AssetUuid : $WANTED_ASSET_UUID." | tee -a "$LOG_FILE"
transfert_data "SELECT CAST(arrow_cast(time, 'Int64') AS VARCHAR) AS epoch_ns, \"AssetUuid\", \"Id\", \"Tag\", \"Type\", CAST(\"Value\" AS VARCHAR) AS \"Value\", CAST(\"CreatedAt\" AS VARCHAR) AS \"CreatedAt\" FROM \"$SOURCE_TABLE\" WHERE \"AssetUuid\" = '$WANTED_ASSET_UUID' $VAR_CONDITION AND \"Tag\" NOT IN $UNWANTED_TAGS AND \"CreatedAt\" >= '$START_TIME_UTC' AND \"CreatedAt\" <= '$END_TIME_UTC'"

# 5) Récupération du dernier timestamp écrit dans la DB TARGET
SQL_QUERY="SELECT CAST(arrow_cast(time, 'Int64') AS VARCHAR) AS epoch_ns FROM \"$TARGET_TABLE\" WHERE \"AssetUuid\" = '$WANTED_ASSET_UUID' $VAR_CONDITION AND \"CreatedAt\" >= '$START_TIME_UTC' AND \"CreatedAt\" <= '$END_TIME_UTC' ORDER BY time DESC LIMIT 1"
RESPONSE=$("$SCRIPT_DIR/simple_request.sh" "$INFLUX_URL" "$INFLUX_TOKEN" "$TARGET_DB" "$SQL_QUERY")
if [ $? -ne 0 ]; then
    handle_error "[x] Erreur d'une requête sur influxdb3 (script simple_request.sh)."
fi
LAST_TIME=$(echo "$RESPONSE" | jq -r '.epoch_ns // empty' 2>/dev/null)
# Si la variable est vide ou contient la chaîne "null", on l'initialise à 0 sans crasher
if [ -z "$LAST_TIME" ] || [ "$LAST_TIME" == "null" ]; then
    LAST_TIME=0
    echo "[~] Aucun timestamp récupéré (aucune donnée précédente transférée). LAST_TIME initialisé à 0." | tee -a "$LOG_FILE"
else
    echo "[~] Timestamp en nanosecondes de la colonne \"time\" de la dernière donnée transférée dans la DB $TARGET_DB : $LAST_TIME" | tee -a "$LOG_FILE"
fi

# 6) Période de buffer pour vérifier les données manquantes
END_BUFFER_TIME_LOCAL=$(( $(date +%s) + BUFFER_TIME ))
echo "[~] Début de la période de buffer de ${BUFFER_TIME} secondes à $(TZ="$TIMEZONE" date "+%H:%M:%S") heure locale ($TIMEZONE). Fin prévue vers $(TZ="$TIMEZONE" date -d "@$END_BUFFER_TIME_LOCAL" '+%H:%M:%S') heure locale ($TIMEZONE)." | tee -a "$LOG_FILE"
sleep $BUFFER_TIME
# 6.1) Comptage du nombre de données manquantes
if [ "$LAST_TIME" -gt 0 ]; then
    count_number_lines "SELECT COUNT(\"AssetUuid\") AS total_count FROM \"$SOURCE_TABLE\" WHERE \"AssetUuid\" = '$WANTED_ASSET_UUID' $VAR_CONDITION AND \"Tag\" NOT IN $UNWANTED_TAGS AND \"CreatedAt\" >= '$START_TIME_UTC' AND \"CreatedAt\" <= '$END_TIME_UTC' AND time > arrow_cast($LAST_TIME, 'Timestamp(Nanosecond, None)')"
    REMAINING_COUNT=$(echo "$RESPONSE_COUNT_DATA" | jq -r '.total_count // 0')
    BUFFER_NUMBER_LINES_TRANSFERRED=$REMAINING_COUNT
else
    REMAINING_COUNT=0
fi
if [ "$REMAINING_COUNT" = "0" ]; then
    echo "[~] Buffer : aucune nouvelle donnée manquante détectée." | tee -a "$LOG_FILE"
else
    echo "[!] Buffer : $REMAINING_COUNT nouvelles données manquantes détectées." | tee -a "$LOG_FILE"
    # 6.2) Transfert des données manquantes
    transfert_data "SELECT CAST(arrow_cast(time, 'Int64') AS VARCHAR) AS epoch_ns, \"AssetUuid\", \"Id\", \"Tag\", \"Type\", CAST(\"Value\" AS VARCHAR) AS \"Value\", CAST(\"CreatedAt\" AS VARCHAR) AS \"CreatedAt\" FROM \"$SOURCE_TABLE\" WHERE \"AssetUuid\" = '$WANTED_ASSET_UUID' $VAR_CONDITION AND \"Tag\" NOT IN $UNWANTED_TAGS AND \"CreatedAt\" >= '$START_TIME_UTC' AND \"CreatedAt\" <= '$END_TIME_UTC' AND time > arrow_cast($LAST_TIME, 'Timestamp(Nanosecond, None)')"
fi

# Mettre à jour le Statut dans l'UNS vers Processed
dialog_with_uns "UPDATE VariableRecordingRequest SET Statut = 'Processed' WHERE Id = '$VARIABLE_RECORDING_REQUEST_ID';" "Impossible de joindre SQL Server pour mettre à jour le statut vers Processed."

# Fin du script 
TOTAL_NUMBER_LINES_TRANSFERRED=$((TOTAL_NUMBER_LINES_TRANSFERRED + BUFFER_NUMBER_LINES_TRANSFERRED))
END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))
# Temps de fin du transfert en UTC
TRANSFERT_END_TIME_UTC=$(date -u +"%Y-%m-%dT%H:%M:%S")
# Créer un enregistrement dans la table VariableRecordingLogs pour le transfert
dialog_with_uns "INSERT INTO VariableRecordingLogs (VariableRecoringId, EquipmentId, VariableId, TransfertStartTime, TransfertEndTime, Duration, TotalNumberLinesTransfered, NumberLinesTransferedDuringBuffer, ErrorMessage) VALUES ('${VARIABLE_RECORDING_REQUEST_ID}', ${EQUIPMENT_ID}, ${VARIABLE_ID}, '${TRANSFERT_START_TIME_UTC}', '${TRANSFERT_END_TIME_UTC}', '${DURATION}', '${TOTAL_NUMBER_LINES_TRANSFERRED}', '${BUFFER_NUMBER_LINES_TRANSFERRED}', '${SQL_ERR_MSG}');" "Impossible de joindre SQL Server pour créer un enregistrement dans VariableRecordingLogs."

printf '[*] Temps écoulé depuis le lancement du script: %02d:%02d:%02d\n' $((DURATION / 3600)) $(((DURATION % 3600) / 60)) $((DURATION % 60))
echo "[~] Script terminé. Statut = 'Processed', Transfert de ${TOTAL_NUMBER_LINES_TRANSFERRED} lignes dont ${BUFFER_NUMBER_LINES_TRANSFERRED} durant la période du buffer, Durée = ${DURATION} secondes, Début = $(TZ="$TIMEZONE" date -d "${TRANSFERT_START_TIME_UTC} UTC" +"%Y-%m-%dT%H:%M:%S") heure locale ($TIMEZONE), Fin = $(TZ="$TIMEZONE" date -d "${TRANSFERT_END_TIME_UTC} UTC" +"%Y-%m-%dT%H:%M:%S") heure locale ($TIMEZONE)." | tee -a "$LOG_FILE"
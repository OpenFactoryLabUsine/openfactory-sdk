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
WANTED_ASSET_UUID="NULL"
UNS_EQUIPMENT_NAME="NULL"
WANTED_DATA_ITEM_ID="NULL"
UNS_VARIABLE_NAME="NULL"

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
    local IS_FROM_ERROR_HANDLER="${3:-false}"
    local sql_output
    sql_output=$(sqlcmd -S "$DB_SERVER" -d "$DB_NAME" -U "$DB_USER" -P "$DB_PASS" -C -b -Q "$SQL_QUERY" 2>&1)
    
    if [ $? -ne 0 ]; then
        if [ "$IS_FROM_ERROR_HANDLER" = "true" ]; then
            echo "[x] Erreur fatale de SQL Server lors de l'enregistrement des logs (UPDATE/INSERT) :" | tee -a "$LOG_FILE"
            echo "$sql_output" | tee -a "$LOG_FILE"
            exit 1
        else
            handle_error "$SQL_ERR_MSG (Détail: $sql_output)" "true"
        fi
    fi
}

handle_error() {
    local msg="$1"
    local is_uns_connexion_error="${2:-"false"}"
    echo "[x] $msg" | tee -a "$LOG_FILE"
    STATUT="Failed"
    SQL_ERR_MSG="'${msg//\'/\'\'}'"
    TRANSFERT_END_TIME_UTC=$(date -u +"%Y-%m-%dT%H:%M:%S")
    DURATION=$(( $(date +%s) - START_TS ))
    
    if [ "$is_uns_connexion_error" = "true" ]; then
        exit 1
    else
        dialog_with_uns "UPDATE VariableRecordingRequest SET Statut = 'Failed' WHERE id = '${VARIABLE_RECORDING_REQUEST_ID}';" "" "true"
        dialog_with_uns "INSERT INTO VariableRecordingLogs (VariableRecordingRequestId, UnsEquipmentName, OpenFactoryAssetUuid, UnsVariableName, OpenFactoryDataItemId, TransfertStartTime, TransfertEndTime, Duration, TotalNumberLinesTransfered, NumberLinesTransferedDuringBuffer, ErrorMessage) VALUES ('${VARIABLE_RECORDING_REQUEST_ID}', ${UNS_EQUIPMENT_NAME}, ${WANTED_ASSET_UUID}, ${UNS_VARIABLE_NAME}, ${WANTED_DATA_ITEM_ID}, '${TRANSFERT_START_TIME_UTC}', '${TRANSFERT_END_TIME_UTC}', '${DURATION}', '${TOTAL_NUMBER_LINES_TRANSFERRED}', '${BUFFER_NUMBER_LINES_TRANSFERRED}', ${SQL_ERR_MSG});" "" "true"
    fi
    exit 1
}

check_if_uns_data_exists() {
    local SQL_QUERY="$1"
    local VAR_TO_ASSIGN="$2"
    local ERR_MSG_CONN="${3:-"Impossible de joindre SQL Server ou requête invalide."}"
    local ERR_MSG_EMPTY="${4:-"Aucune donnée correspondante trouvée dans UNS. Veuillez vérifier vos entrées."}"
    local fetched_data
    
    fetched_data=$(sqlcmd -S "$DB_SERVER" -d "$DB_NAME" -U "$DB_USER" -P "$DB_PASS" -C -b -h -1 -W -Q "$SQL_QUERY" 2>/dev/null)
    if [ $? -ne 0 ]; then
        handle_error "$ERR_MSG_CONN" "true"
    fi
    fetched_data=$(echo "$fetched_data" | xargs)
    if [ -z "$fetched_data" ] || [ "$fetched_data" == "NULL" ]; then
        handle_error "$ERR_MSG_EMPTY"
    fi
    printf -v "$VAR_TO_ASSIGN" "%s" "$fetched_data"
}

get_variable_recording_request_data() {
    local query="SET NOCOUNT ON; SELECT COALESCE(CAST(EquipmentId AS VARCHAR), 'NULL_VALUE'), COALESCE(CAST(VariableId AS VARCHAR), 'NULL_VALUE'), Statut, LocalStartTime, LocalEndTime, BufferTime, TimeZone FROM VariableRecordingRequest WHERE id = '$VARIABLE_RECORDING_REQUEST_ID';"
    data=$(sqlcmd -S "$DB_SERVER" -d "$DB_NAME" -U "$DB_USER" -P "$DB_PASS" -C -b -h -1 -W -s "|" -Q "$query" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$data" ]; then
        handle_error "Impossible de joindre SQL Server." "true"
    fi
    IFS='|' read -r WANTED_EQUIPMENT_ID WANTED_VARIABLE_ID STATUT LOCAL_START_TIME LOCAL_END_TIME BUFFER_TIME TIMEZONE <<< "$data"

    # Vérification des IDs
    if [[ "$WANTED_VARIABLE_ID" == 'NULL_VALUE' && "$WANTED_EQUIPMENT_ID" == 'NULL_VALUE' ]]; then
        handle_error "La demande d'enregistrement avec l'ID $VARIABLE_RECORDING_REQUEST_ID ne contient ni EquipmentId ni VariableId." "true" 
    elif [[ "$WANTED_VARIABLE_ID" != 'NULL_VALUE' && "$WANTED_EQUIPMENT_ID" != 'NULL_VALUE' ]]; then
        check_if_uns_data_exists "SET NOCOUNT ON; SELECT Id FROM Equipment WHERE Id = '$WANTED_EQUIPMENT_ID';" "WANTED_EQUIPMENT_ID"
        check_if_uns_data_exists "SET NOCOUNT ON; SELECT Id FROM Variable WHERE Id = '$WANTED_VARIABLE_ID' AND EquipmentId = '$WANTED_EQUIPMENT_ID';" "WANTED_VARIABLE_ID" "Erreur." "Variable introuvable pour cet équipement."
    elif [ "$WANTED_EQUIPMENT_ID" != 'NULL_VALUE' ]; then
        check_if_uns_data_exists "SET NOCOUNT ON; SELECT Id FROM Equipment WHERE Id = '$WANTED_EQUIPMENT_ID';" "WANTED_EQUIPMENT_ID"
    elif [ "$WANTED_VARIABLE_ID" != 'NULL_VALUE' ]; then
        check_if_uns_data_exists "SET NOCOUNT ON; SELECT Id FROM Variable WHERE Id = '$WANTED_VARIABLE_ID';" "WANTED_VARIABLE_ID"
    fi

    # Récupération AssetUuid et Noms
    if [[ "$WANTED_EQUIPMENT_ID" != 'NULL_VALUE' ]]; then
        local raw_uuid=""
        local raw_eq_name=""
        check_if_uns_data_exists "SET NOCOUNT ON; SELECT OpenFactoryAssetUuid FROM Equipment WHERE Id = '$WANTED_EQUIPMENT_ID';" "raw_uuid"
        INFLUX_ASSET_UUID="$raw_uuid"
        WANTED_ASSET_UUID="'${raw_uuid//\'/\'\'}'"
        
        check_if_uns_data_exists "SET NOCOUNT ON; SELECT UnsEquipmentName FROM Equipment WHERE Id = '$WANTED_EQUIPMENT_ID';" "raw_eq_name"
        UNS_EQUIPMENT_NAME="'${raw_eq_name//\'/\'\'}'"
    else
        INFLUX_ASSET_UUID="NULL"
    fi
    
    if [[ "$WANTED_VARIABLE_ID" != 'NULL_VALUE' ]]; then
        local raw_data_id=""
        local raw_var_name=""
        check_if_uns_data_exists "SET NOCOUNT ON; SELECT OpenFactoryDataItemId FROM Variable WHERE Id = '$WANTED_VARIABLE_ID';" "raw_data_id"
        INFLUX_DATA_ITEM_ID="$raw_data_id"
        WANTED_DATA_ITEM_ID="'${raw_data_id//\'/\'\'}'"
        
        check_if_uns_data_exists "SET NOCOUNT ON; SELECT UnsVariableName FROM Variable WHERE Id = '$WANTED_VARIABLE_ID';" "raw_var_name"
        UNS_VARIABLE_NAME="'${raw_var_name//\'/\'\'}'"
    else
        INFLUX_DATA_ITEM_ID="NULL"
    fi

    if [[ "$STATUT" = "Processed" || "$STATUT" = "InProgress" || "$STATUT" = "TelegrafAutomation" ]]; then
        handle_error "La demande est en statut $STATUT, impossible de lancer le script."
    elif [[ -z "$LOCAL_END_TIME" || "$LOCAL_END_TIME" < "$LOCAL_START_TIME" || ! "$LOCAL_END_TIME" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$ || ! "$LOCAL_START_TIME" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
        handle_error "Dates locales invalides (incohérence ou format). Veuillez vérifier."
    fi
}
get_variable_recording_request_data

count_number_lines(){
    local sql_query=$1
    RESPONSE_COUNT_DATA=$("$SCRIPT_DIR/simple_request.sh" "$INFLUX_URL" "$INFLUX_TOKEN" "$SOURCE_DB" "$sql_query")
    if [ $? -ne 0 ]; then handle_error "[x] Erreur requête count influxdb3."; fi
}

transfert_data(){
    local sql_query=$1
    "$SCRIPT_DIR/data_transfert.sh" "$INFLUX_URL" "$INFLUX_TOKEN" "$SOURCE_DB" "$TARGET_DB" "$sql_query" "$CHUNK_SIZE" "$TARGET_TABLE"
    if [ $? -ne 0 ]; then handle_error "[x] Erreur transfert data_transfert.sh."; fi
}

# Construction dynamique de VAR_CONDITION
if [[ "$INFLUX_ASSET_UUID" != "NULL" && "$INFLUX_DATA_ITEM_ID" != "NULL" ]]; then
    VAR_CONDITION="WHERE \"AssetUuid\" = '$INFLUX_ASSET_UUID' AND \"Id\" = '$INFLUX_DATA_ITEM_ID' AND \"Tag\" NOT IN $UNWANTED_TAGS" 
elif [[ "$INFLUX_ASSET_UUID" != "NULL" ]]; then
    VAR_CONDITION="WHERE \"AssetUuid\" = '$INFLUX_ASSET_UUID' AND \"Tag\" NOT IN $UNWANTED_TAGS"
elif [[ "$INFLUX_DATA_ITEM_ID" != "NULL" ]]; then
    VAR_CONDITION="WHERE \"Id\" = '$INFLUX_DATA_ITEM_ID' AND \"Tag\" NOT IN $UNWANTED_TAGS"
fi

# 1) Mettre à jour le Statut dans l'UNS vers InProgress
dialog_with_uns "UPDATE VariableRecordingRequest SET Statut = 'InProgress' WHERE id = '$VARIABLE_RECORDING_REQUEST_ID';" "Impossible de Modifier le statut à InProgress."

# 2) Convertir les heures locales en UTC
EPOCH_START=$(TZ="$TIMEZONE" date -d "${LOCAL_START_TIME/T/ }" +"%s")
EPOCH_END=$(TZ="$TIMEZONE" date -d "${LOCAL_END_TIME/T/ }" +"%s")
START_TIME_UTC=$(date -u -d "@$EPOCH_START" +"%Y-%m-%dT%H:%M:%SZ")
END_TIME_UTC=$(date -u -d "@$EPOCH_END" +"%Y-%m-%dT%H:%M:%SZ")

BASE_WHERE_CLAUSE="$VAR_CONDITION AND \"CreatedAt\" >= '$START_TIME_UTC' AND \"CreatedAt\" <= '$END_TIME_UTC'"

build_queries() {
    local extra_condition="$1"
    local current_where="$BASE_WHERE_CLAUSE"
    if [ -n "$extra_condition" ]; then
        current_where="$current_where AND $extra_condition"
    fi
    
    CURRENT_COUNT_QUERY="SELECT COUNT(\"AssetUuid\") AS total_count FROM \"$SOURCE_TABLE\" $current_where"
    CURRENT_TRANSFER_QUERY="SELECT CAST(arrow_cast(time, 'Int64') AS VARCHAR) AS epoch_ns, \"AssetUuid\", \"Id\", \"Tag\", \"Type\", CAST(\"Value\" AS VARCHAR) AS \"Value\", CAST(\"CreatedAt\" AS VARCHAR) AS \"CreatedAt\" FROM \"$SOURCE_TABLE\" $current_where"
}

echo "[~] Début du script. AssetUuid : $INFLUX_ASSET_UUID, VariableDataItemId : $INFLUX_DATA_ITEM_ID, période : $START_TIME_UTC à $END_TIME_UTC. (UTC)"  | tee -a "$LOG_FILE"

# 3) Génération et exécution du comptage initial
build_queries ""
count_number_lines "$CURRENT_COUNT_QUERY"
TOTAL_NUMBER_LINES_TRANSFERRED=$(echo "$RESPONSE_COUNT_DATA" | jq -r '.total_count // 0')

# 4) Transfert
echo "[~] Lancement du transfert de $TOTAL_NUMBER_LINES_TRANSFERRED lignes de la DB $SOURCE_DB vers la DB $TARGET_DB." | tee -a "$LOG_FILE"
transfert_data "$CURRENT_TRANSFER_QUERY"

# 5) Récupération du dernier timestamp
SQL_QUERY_LAST_TIME="SELECT CAST(arrow_cast(time, 'Int64') AS VARCHAR) AS epoch_ns FROM \"$TARGET_TABLE\" $VAR_CONDITION AND \"CreatedAt\" >= '$START_TIME_UTC' AND \"CreatedAt\" <= '$END_TIME_UTC' ORDER BY time DESC LIMIT 1"
RESPONSE=$("$SCRIPT_DIR/simple_request.sh" "$INFLUX_URL" "$INFLUX_TOKEN" "$TARGET_DB" "$SQL_QUERY_LAST_TIME")
if [ $? -ne 0 ]; then handle_error "[x] Erreur requête dernier timestamp."; fi
LAST_TIME=$(echo "$RESPONSE" | jq -r '.epoch_ns // empty' 2>/dev/null)

if [ -z "$LAST_TIME" ] || [ "$LAST_TIME" == "null" ]; then
    LAST_TIME=0
    echo "[~] Aucun timestamp récupéré. LAST_TIME = 0." | tee -a "$LOG_FILE"
else
    echo "[~] Dernier timestamp (nanosecondes) : $LAST_TIME" | tee -a "$LOG_FILE"
fi

# 6) Buffer
END_BUFFER_TIME_LOCAL=$(( $(date +%s) + BUFFER_TIME ))
echo "[~] Période de buffer de ${BUFFER_TIME}s. Fin prévue : $(TZ="$TIMEZONE" date -d "@$END_BUFFER_TIME_LOCAL" '+%H:%M:%S')." | tee -a "$LOG_FILE"
sleep $BUFFER_TIME

if [ "$LAST_TIME" -gt 0 ]; then
    build_queries "time > arrow_cast($LAST_TIME, 'Timestamp(Nanosecond, None)')"
    count_number_lines "$CURRENT_COUNT_QUERY"
    REMAINING_COUNT=$(echo "$RESPONSE_COUNT_DATA" | jq -r '.total_count // 0')
    BUFFER_NUMBER_LINES_TRANSFERRED=$REMAINING_COUNT
else
    REMAINING_COUNT=0
fi

if [ "$REMAINING_COUNT" = "0" ]; then
    echo "[~] Buffer : aucune nouvelle donnée manquante détectée." | tee -a "$LOG_FILE"
else
    echo "[!] Buffer : $REMAINING_COUNT nouvelles données manquantes détectées." | tee -a "$LOG_FILE"
    transfert_data "$CURRENT_TRANSFER_QUERY"
fi

dialog_with_uns "UPDATE VariableRecordingRequest SET Statut = 'Processed' WHERE Id = '$VARIABLE_RECORDING_REQUEST_ID';" "Erreur statut Processed."

# Fin
TOTAL_NUMBER_LINES_TRANSFERRED=$((TOTAL_NUMBER_LINES_TRANSFERRED + BUFFER_NUMBER_LINES_TRANSFERRED))
END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))
TRANSFERT_END_TIME_UTC=$(date -u +"%Y-%m-%dT%H:%M:%S")

dialog_with_uns "INSERT INTO VariableRecordingLogs (VariableRecordingRequestId, UnsEquipmentName, OpenFactoryAssetUuid, UnsVariableName, OpenFactoryDataItemId, TransfertStartTime, TransfertEndTime, Duration, TotalNumberLinesTransfered, NumberLinesTransferedDuringBuffer, ErrorMessage) VALUES ('${VARIABLE_RECORDING_REQUEST_ID}', ${UNS_EQUIPMENT_NAME}, ${WANTED_ASSET_UUID}, ${UNS_VARIABLE_NAME}, ${WANTED_DATA_ITEM_ID}, '${TRANSFERT_START_TIME_UTC}', '${TRANSFERT_END_TIME_UTC}', '${DURATION}', '${TOTAL_NUMBER_LINES_TRANSFERRED}', '${BUFFER_NUMBER_LINES_TRANSFERRED}', ${SQL_ERR_MSG});" "Erreur log final."

printf '[*] Temps écoulé: %02d:%02d:%02d\n' $((DURATION / 3600)) $(((DURATION % 3600) / 60)) $((DURATION % 60))
echo "[~] Terminé. Statut='Processed', Lignes=${TOTAL_NUMBER_LINES_TRANSFERRED}, Buffer=${BUFFER_NUMBER_LINES_TRANSFERRED}, Durée=${DURATION}s." | tee -a "$LOG_FILE"
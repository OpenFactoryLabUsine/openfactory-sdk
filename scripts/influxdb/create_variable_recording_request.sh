#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "[x] Fichier .env introuvable. Veuillez créer un fichier .env à la racine du projet avec les variables d'environnement nécessaires."
    exit 1
fi

# Configuration
IS_AUTOMATED="false"
UNS_EQUIPMENT_ID=${1:-"NULL"}
UNS_VARIABLE_ID=${2:-"NULL"}
LOCAL_START_TIME=${3:-""}
LOCAL_END_TIME=${4:-""}
MPS=${5:-""}
BUFFER_TIME=${6:-""}
TIME_ZONE=${7:-"America/Toronto"}

# Configuration UNS
DB_SERVER=$DB_SERVER
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS

check_data_information() {
    local variable="$1"
    if [ -z "$variable" ]; then
        echo "[x] Vous devez fournir l'information requise. Veuillez réessayer."
        return 1
    fi
    return 0
}

check_if_uns_data_exists() {
    local SQL_QUERY="$1"
    data=$(sqlcmd -S "$DB_SERVER" -d "$DB_NAME" -U "$DB_USER" -P "$DB_PASS" -C -h -1 -W -Q "$SQL_QUERY" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "[x] Impossible de joindre SQL Server." >&2
        exit 1
    fi
    if [ -z "$data" ]; then
        echo "[x] Aucune donnée correspondante trouvée dans UNS. Veuillez vérifier vos entrées." >&2
        return 1
    fi
    echo "$data"
    return 0
}

update_uns() {
    local SQL_QUERY="$1"
    sqlcmd -S "$DB_SERVER" -d "$DB_NAME" -U "$DB_USER" -P "$DB_PASS" -C -Q "$SQL_QUERY" > /dev/null
    if [ $? -ne 0 ]; then
        echo "[x] Impossible de joindre SQL Server." >&2
        exit 1
    fi
    return $?
}

get_uns_data() {
    local SQL_QUERY="$1"
    data=$(sqlcmd -S "$DB_SERVER" -d "$DB_NAME" -U "$DB_USER" -P "$DB_PASS" -C -W -Q "$SQL_QUERY" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "[x] Impossible de joindre SQL Server." >&2
        exit 1
    fi
    echo "$data"
}

check_if_data_is_integer() {
    local variable="$1"
    if ! [[ "$variable" =~ ^[0-9]+$ ]]; then
        echo "[x] La valeur fournie n'est pas un entier valide. Veuillez réessayer."
        return 1
    fi
    return 0
}

check_if_data_is_timestamp() {
    local variable="$1"
    if ! [[ "$variable" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
        echo "[x] La valeur fournie n'est pas un timestamp valide. Veuillez réessayer."
        return 1
    fi
    return 0
}

if [ "$UNS_EQUIPMENT_ID" != "NULL" ]; then
    IS_AUTOMATED="true"
fi

if [ "$IS_AUTOMATED" == "true" ]; then
    echo "Mode automatique"
else
    clear
    echo "Mode manuel"

    echo "--- Sélection du nom de l'équipement à enregistrer ---"
    get_uns_data "SET NOCOUNT ON; SELECT UnsEquipmentName FROM Equipment;"
    while true; do
        read -p "[Facultatif] Entrez le nom de l'équipement souhaité : " UNS_EQUIPMENT_NAME_RESPONSE
        # Si la fonction retourne 1 (erreur), "|| continue" renvoie au début de la boucle
        if [ -n "$UNS_EQUIPMENT_NAME_RESPONSE" ]; then
            UNS_EQUIPMENT_ID=$(check_if_uns_data_exists "SET NOCOUNT ON; SELECT Id FROM Equipment WHERE UnsEquipmentName = '$UNS_EQUIPMENT_NAME_RESPONSE';") || continue
        else
            UNS_EQUIPMENT_ID="NULL"
        fi
        break # Sortie de la boucle si tout est OK
    done


    echo -e "\n --- Sélection de la variable à enregistrer ---"
    if [ "$UNS_EQUIPMENT_ID" != "NULL" ]; then
        get_uns_data "SET NOCOUNT ON; SELECT UnsVariableName FROM Variable WHERE EquipmentId = $UNS_EQUIPMENT_ID;"
    else
        get_uns_data "SET NOCOUNT ON; SELECT UnsVariableName FROM Variable;"
    fi

    while true; do
        read -p "[Facultatif] Entrez le nom de la variable pour n'enregistrer qu'un capteur spécifique de l'équipement sélectionné : " UNS_VARIABLE_NAME_RESPONSE
        echo "UNS_VARIABLE_NAME_RESPONSE: $UNS_VARIABLE_NAME_RESPONSE"
        if [[ -n "$UNS_VARIABLE_NAME_RESPONSE" && "$UNS_EQUIPMENT_ID" != "NULL" ]]; then
            UNS_VARIABLE_ID=$(check_if_uns_data_exists "SET NOCOUNT ON; SELECT Id FROM Variable WHERE UnsVariableName = '$UNS_VARIABLE_NAME_RESPONSE' AND EquipmentId = $UNS_EQUIPMENT_ID;") || continue
        elif [[ -n "$UNS_VARIABLE_NAME_RESPONSE" && "$UNS_EQUIPMENT_ID" == "NULL" ]]; then
            UNS_VARIABLE_ID=$(check_if_uns_data_exists "SET NOCOUNT ON; SELECT Id FROM Variable WHERE UnsVariableName = '$UNS_VARIABLE_NAME_RESPONSE';") || continue
        else
            UNS_VARIABLE_ID="NULL"
        fi
        break
    done

    clear

    while true; do
        read -p "[Obligatoire] Entrez l'heure de début d'enregistrement dans votre TimeZone (format: YYYY-MM-DDTHH:MM:SS) (exemple: 2026-06-26T13:15:17) : " LOCAL_START_TIME
        check_data_information "$LOCAL_START_TIME" || continue
        check_if_data_is_timestamp "$LOCAL_START_TIME" || continue
        break
    done

    clear

    while true; do
        read -p "[Facultatif] Entrez l'heure de fin d'enregistrement dans votre TimeZone (format: YYYY-MM-DDTHH:MM:SS) (exemple: 2026-06-26T13:15:17) : " LOCAL_END_TIME
        if [ -z "$LOCAL_END_TIME" ]; then
            LOCAL_END_TIME="NULL"
        else
            check_if_data_is_timestamp "$LOCAL_END_TIME" || continue
            LOCAL_END_TIME="'$LOCAL_END_TIME'"
        fi
        break
    done

    while true; do
        read -p "[Facultatif] Entrez votre TimeZone (exemple: America/Toronto) (défaut: America/Toronto) : " TIME_ZONE
        if [ -z "$TIME_ZONE" ]; then
            TIME_ZONE="America/Toronto"
        fi
        
        if ! [[ "$TIME_ZONE" =~ ^[A-Za-z]+/[A-Za-z_-]+$ ]]; then
            echo "[x] La valeur fournie n'est pas un TimeZone valide. Veuillez réessayer."
            continue
        fi
        break
    done

    while true; do
        read -p "[Obligatoire] Entrez le temps de buffer (en secondes) (exemple: 120) : " BUFFER_TIME
        check_data_information "$BUFFER_TIME" || continue
        check_if_data_is_integer "$BUFFER_TIME" || continue
        break
    done

    while true; do
        read -p "[Facultatif] Entrez le MPS (mesures par seconde) (en secondes) (exemple: 60) : " MPS
        if [ -z "$MPS" ]; then
            MPS="NULL"
        else
            check_if_data_is_integer "$MPS" || continue
            MPS="$MPS"
        fi
        break
    done
fi

echo "Création de la demande d'enregistrement de variable dans UNS..."
message=$(update_uns "INSERT INTO VariableRecordingRequest (EquipmentId, VariableId, Statut, LocalStartTime, LocalEndTime, Mps, BufferTime, TimeZone) VALUES ($UNS_EQUIPMENT_ID, $UNS_VARIABLE_ID, 'Planned', '$LOCAL_START_TIME', $LOCAL_END_TIME, $MPS, '$BUFFER_TIME', '$TIME_ZONE');")
echo "$message"
if [ $? -ne 0 ]; then
    echo "[x] Impossible de joindre SQL Server pour ajouter la demande d'enregistrement." >&2
    exit 1
else
    echo "[✓] Demande d'enregistrement de variable créée avec succès dans l'UNS."
fi
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"
if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "[x] Fichier .env introuvable. Veuillez créer un fichier .env à la racine du projet avec les variables d'environnement nécessaires."
    exit 1
fi
# Configuration
IS_AUTOMATED="false"
WANTED_ASSET_UUID=${1:-""}
WANTED_VARIABLE_NAME=${2:-"NULL"}
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
        exit 1
    fi
}

check_if_uns_data_exists() {
    local SQL_QUERY="$1"
    data=$(sqlcmd -S "$DB_SERVER" -d "$DB_NAME" -U "$DB_USER" -P "$DB_PASS" -C -h -1 -W -Q "$SQL_QUERY" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "[x] Impossible de joindre SQL Server." >&2
        exit 1
    fi
    if [ -z "$data" ]; then
        echo "[x] Aucune donnée correspondante trouvée dans UNS. Veuillez vérifier vos entrées."
        exit 1
    fi
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
    clear
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
        exit 1
    fi
}

check_if_data_is_timestamp() {
    local variable="$1"
    if ! [[ "$variable" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
        echo "[x] La valeur fournie n'est pas un timestamp valide. Veuillez réessayer."
        exit 1
    fi
}

if [ $WANTED_ASSET_UUID ]; then
    IS_AUTOMATED="true"
fi

if [ "$IS_AUTOMATED" == "true" ]; then
  echo "Mode automatique"
else
  clear
  echo "Mode manuel"

  echo "--- Sélection de l'équipement Uuid à enregistrer ---"
  get_uns_data "SET NOCOUNT ON; SELECT AssetUuid FROM Equipment;"

  read -p "[Obligatoire] Entrez l'UUID de l'équipement souhaité : " WANTED_ASSET_UUID
  check_data_information "$WANTED_ASSET_UUID"
  check_if_uns_data_exists "SET NOCOUNT ON; SELECT id FROM Equipment WHERE AssetUuid = '$WANTED_ASSET_UUID';"

  echo -e "\n --- Sélection de la variable à enregistrer ---"
  get_uns_data "SET NOCOUNT ON; SELECT Nom FROM Variable WHERE EquipmentId IN (SELECT id FROM Equipment WHERE AssetUuid = '$WANTED_ASSET_UUID');"

  read -p "[Facultatif] Entrez le nom de la variable pour n'enregistrer qu'un capteur spécifique de l'équipement sélectionné : " 'WANTED_VARIABLE_NAME_RESPONSE'
  if [ -n "$WANTED_VARIABLE_NAME_RESPONSE" ]; then
    WANTED_VARIABLE_NAME="'$WANTED_VARIABLE_NAME_RESPONSE'"
    check_if_uns_data_exists "SET NOCOUNT ON; SELECT Nom FROM Variable WHERE Nom = $WANTED_VARIABLE_NAME AND EquipmentId IN (SELECT id FROM Equipment WHERE AssetUuid = '$WANTED_ASSET_UUID');"
  else
    WANTED_VARIABLE_NAME="NULL"
  fi

  clear

  read -p "[Obligatoire] Entrez l'heure de début d'enregistrement dans votre TimeZone (format: YYYY-MM-DDTHH:MM:SS) (exemple: 2026-06-26T13:15:17) : " LOCAL_START_TIME
  check_data_information "$LOCAL_START_TIME"
  check_if_data_is_timestamp "$LOCAL_START_TIME"

  read -p "[Obligatoire] Entrez l'heure de fin d'enregistrement dans votre TimeZone (format: YYYY-MM-DDTHH:MM:SS) (exemple: 2026-06-26T13:15:17) : " LOCAL_END_TIME
  check_data_information "$LOCAL_END_TIME"
  check_if_data_is_timestamp "$LOCAL_END_TIME"

  read -p "[Facultatif] Entrez votre TimeZone (exemple: America/Toronto) (défaut: America/Toronto) : " TIME_ZONE
  if [ -z "$TIME_ZONE" ]; then
    TIME_ZONE="America/Toronto"
  fi
  if ! [[ "$TIME_ZONE" =~ ^[A-Za-z]+/[A-Za-z_-]+$ ]]; then
    echo "[x] La valeur fournie n'est pas un TimeZone valide. Veuillez réessayer."
    exit 1
  fi

  read -p "[Obligatoire] Entrez le temps de buffer (en secondes) (exemple: 120) : " BUFFER_TIME
  check_data_information "$BUFFER_TIME"
  check_if_data_is_integer "$BUFFER_TIME"

  read -p "[Obligatoire] Entrez le MPS (mesures par seconde) (en secondes) (exemple: 60) : " MPS
  check_data_information "$MPS"
  check_if_data_is_integer "$MPS"
fi

echo "Création de la demande d'enregistrement de variable dans UNS..."
update_uns "INSERT INTO VariableRecordingRequest (WantedVariableName, WantedAssetUuid, Statut, LocalStartTime, LocalEndTime, Mps, BufferTime, TimeZone) VALUES ($WANTED_VARIABLE_NAME, '$WANTED_ASSET_UUID', 'Planned', '$LOCAL_START_TIME', '$LOCAL_END_TIME', '$MPS', '$BUFFER_TIME', '$TIME_ZONE');"
if [ $? -ne 0 ]; then
    echo "[x] Impossible de joindre SQL Server pour ajouter la demande d'enregistrement." >&2
    exit 1
else
    echo "[✓] Demande d'enregistrement de variable créée avec succès dans l'UNS."
fi
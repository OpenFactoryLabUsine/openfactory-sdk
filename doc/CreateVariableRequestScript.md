# create_variable_recording_request.sh
Script permettant de créer une entrée dans la table `VariableRecordingRequest` nécessaire pour exécuter le script `pipeline.sh` par la suite.

## Prérequis
### Installer sqlcmd
```bash
sudo apt udpate -y && sudo apt install mssql-tools18 unixodbc-dev
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
source ~/.bashrc
```

### Créer le fichier .env
A la racine du projet : 
`cp .env.dev .env`
Compléter les entrées.

## Utilisation
Il est possible de l’utiliser en mode `manuel` en l’exécutant sans argument : `./create_variable_recording_request.sh`.
Il est aussi possible de l’utiliser en mode `automatique` en transmettant les arguments sous cette forme : 

**Syntaxe :**
```bash
./create_variable_recording_request.sh "WANTED_ASSET_UUID" "WANTED_VARIABLE_NAME" "LocalStartTime" "LocalEndTime" "MesuresParSecondes" "BufferTimeInSeconds" "TIME_ZONE"
```

**Exemple :**
```bash
# Dans ce cas, on ne spécifie pas de WANTED_VARIABLE_NAME donc lors du transfert c'est tous les capteurs du DUSTTRAK qui seront transférés
# On ne spécifie aussi pas de TIME_ZONE, celle par défaut étant America/Toronto 
./scripts/create_variable_recording_request.sh "DUSTTRAK" "" "2026-06-26T13:15:17" "2026-07-28T13:15:15" "120" "3600"
```

# Pipeline.sh
Script permettant de transférer les données d’une DB influxDB3 à une autre grâce à l’enregistrement précédemment renseigné dans la table `VariableRecordingRequest` dans **l’UNS**.

## Prérequis
### Installer sqlcmd
```bash
sudo apt udpate -y && sudo apt install mssql-tools18 unixodbc-dev
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
source ~/.bashrc
```

### Créer le fichier .env
A la racine du projet : 
`cp ./scripts/influxdb/.env.dev ./scripts/influxdb/.env`  

Compléter les entrées.

## Utilisation
Le script s'exécute en ligne de commande et prend un seul argument : l'identifiant de la demande d'enregistrement (ID).

**Syntaxe :**
```bash
./pipeline.sh [VARIABLE_RECORDING_REQUEST_ID]
```

**Exemple :**
```bash
# Lance le transfert pour la requête portant l'ID 5
./pipeline.sh 5
```


## Explications détaillées
1. **Validation de la demande (SQL Server) :** Le script interroge la table `VariableRecordingRequest` avec l'ID fourni. Il récupère la période de temps, l'équipement concerné, le temps de buffer et le fuseau horaire. Le script s'arrête si la demande n'est pas au statut `Planned`.
2. **Verrouillage :** Le statut de la demande passe à `InProgress` dans la base SQL pour éviter les exécutions concurrentes.
3. **Comptage et Transfert initial :**
    - Le script calcule le nombre total de lignes correspondantes dans la période demandée (via `simple_request.sh`).
    - Les données sont lues depuis la base `ephemeral` et insérées dans la base `lifetime` (via `data_transfert.sh`).
4. **Gestion du Buffer (Données retardées) :**
    - Le script récupère le dernier timestamp inséré.
    - Il attend que le BufferTime en secondes soit écoulé pour continuer son exécution.
    - Il vérifie si de nouvelles données (arrivées en retard dans la base source) avec un timestamp supérieur au dernier enregistrement sont présentes.
    - Si oui, elles sont transférées pour garantir l'intégrité de l'historique.
5. **Clôture et Traçabilité :** Le statut de la requête passe à `Processed` dans SQL Server.
    - Un log complet (durée, nombre de lignes transférées, lignes récupérées pendant le buffer, erreurs éventuelles) est inséré dans la table `VariableRecordingLogs`.
        
En cas d'échec à n'importe quelle étape critique (perte de connexion, erreur d'API), la fonction `handle_error` bascule le statut de la demande en `Failed`, insère l'erreur exacte dans les logs SQL et stoppe l'exécution.


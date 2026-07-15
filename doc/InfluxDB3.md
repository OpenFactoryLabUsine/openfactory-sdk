# InfluxDB

## Fonctionnement 
InfluxDB est une base de données faites pour enregistrer d’énorme quantité de données de mesures liées à un timestamp et auquel on peut ajouter des tags pour filtrer plus simplement par la suite.
Ca se présente tel une DB sql classique avec une BDD qui a plusieurs tables pour chaque capteur et chaque table à des colonnes : mesure ; tag(s) ; timestamp.
On peut spécifier une période de rétention ou non.

### Fichiers .wal
Les données enregistrées sont stockées en mémoire RAM et en même temps écrites dans des fichiers `.wal` dans le dossier : `/influxdb3/data/node0/wal/`. Les écrire dans des fichiers wal permet à influxdb de ne pas perdre les données si le service venait à crasher. Il aura alors juste à relire les fichiers .wal pour réécrire les données dans la RAM afin d’y accéder rapidement.

### Transfert des fichiers .wal vers des fichiers .parquet
Les données des fichier .wal sont transférées toutes les 10/15mn vers des fichiers parquets bcp plus optimisés ou quand la RAM est pleine, ou à l’arrêt propre du service. Lors du transfert les fichiers .wal concernés sont supprimés

### Fichiers .parquet
Les fichiers .parquet sont stockés dans le path : `/influxdb3/data/node0/dbs/`
Le format parquet est open source.
Les fichiers Parquet peuvent stocker des images, des vidéos, des objets, des fichiers et des données standard

Stockage en DB normal : 

| Id  | Nom  | Age |
| --- | ---- | --- |
| 1   | bob  | 18  |
| 2   | Alce | 19  |
|     |      |     |
Ici, le moteur doit lire toutes les données même s’il a juste besoin de récupérer `Age`
Stockage en parquet : 

| ID  | 1,2        |
| --- | ---------- |
| Nom | bob, Alice |
| Age | 18, 19     |
Ici, le moteur va juste à la ligne `Age` et lit l’entièreté des données en une fois

## Nom du service docker
IP pour connecter influxDB3 core à influxDB3-explorer : `influxdb-influxdb3-core-1:8181`

## Générer un token
https://docs.influxdata.com/influxdb3/core/get-started/setup/?t=Docker
Commande : 
```bash
docker exec -it influxdb-influxdb3-enterprise-1 influxdb3 create token --admin
```

## Connecter le serveur InfluxDB
_Dans Configure > Servers_ 
Server Name : `N’importe quel nom`
Server URL : `influxdb-influxdb3-core-1:8181`
Token : `le token généré précédemment`

## Créer une DB 
_Dans Manage Databases_ 
Database Name : `N’importe quel nom`
Retention Period : `par exemple 7d`

## Voir les données 
Aller dans _Query Data > Data Explorer > Selectionner ephemeral database_

## API Endpoint pour récupérer les données de l’ancienne base
https://docs.influxdata.com/influxdb3/core/api/query-data/#operation/GetExecuteQuerySQL

## API Endpoint pour enregistrer les données dans la nv base
https://docs.influxdata.com/influxdb3/core/api/write-data/

## Line protocol

### Explications Line protocol
https://docs.influxdata.com/influxdb3/enterprise/reference/line-protocol/

### Tag dont les VALUE associée posent problème pour le line protocol 

| TAG                          | Pose problème ? | Explications                                             |
| ---------------------------- | --------------- | -------------------------------------------------------- |
| DustTrak.pm10_concentration  | X               |                                                          |
| DustTrak.pm1_concentration   | X               |                                                          |
| DustTrak.pm2_5_concentration | X               |                                                          |
| DustTrak.pm4_concentration   | X               |                                                          |
| AssetType                    | X               |                                                          |
| DockerService                | X               |                                                          |
| Application.Manufacturer     | X               |                                                          |
| Application.Version          | X               |                                                          |
| UNSLevel                     | X               |                                                          |
| Availability                 | X               |                                                          |
| Device.Count                 | X               |                                                          |
| OPCUA.Gateway                | X               |                                                          |
| Method                       | Oui             | Il y a des caractères interdits comme : " et des espaces |
| Method.Command               | Oui             | Il y a des caractères interdits comme : "                |
| Application.License          | Oui             | Il y a des espaces                                       |
| Library.License              | Oui             | Il y a des espaces                                       |


## Chemins du repertoire sur la prod
```bash
# Projet lab-usine
/opt/lab-usine/openfactory-LabUsine
# Projet influxdb
/opt/lab-usine/influxdb/
```

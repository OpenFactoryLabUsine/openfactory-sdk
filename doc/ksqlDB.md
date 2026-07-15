# KSQL
## Commandes de base
Pour voir les tables via ksql, se rendre dans le terminal du dev container et faire : 
```bash
ksql;
```
Puis
```bash
SHOW TABLES;
```
Puis
```bash
SELECT * FROM TABLENAME;
```
_Pour voir les nouvelles data automatiquement, ajouter EMIT CHANGES avant le ;_

## Créer un stream
```sql
CREATE STREAM FACTORY_ASSETS_STREAM (
    KEY VARCHAR,
    ASSET_UUID VARCHAR,
    ID VARCHAR,
    VALUE VARCHAR,
    TYPE VARCHAR,
    TAG VARCHAR, 
    TIMESTAMP VARCHAR
) WITH (
        KAFKA_TOPIC='ASSETS',
        VALUE_FORMAT='JSON'
);
```

## Créer un stream pour filtrer les data 
```sql
CREATE STREAM CNC_DATA_STREAM 
WITH (
    KAFKA_TOPIC='CNC_DATA',
    VALUE_FORMAT='JSON'
) AS 
SELECT * FROM FACTORY_ASSETS_STREAM 
WHERE ASSET_UUID = 'CNC'
EMIT CHANGES;
```

```sql
CREATE STREAM DUSTTRAK_DATA_STREAM 
WITH (
    KAFKA_TOPIC='DUSTTRAK_DATA',
    VALUE_FORMAT='JSON'
) AS 
SELECT * FROM FACTORY_ASSETS_STREAM 
WHERE ASSET_UUID = 'DUSTTRAK'
EMIT CHANGES;
```

## Modifier un stream
```sql
CREATE OR REPLACE STREAM CNC_DATA_STREAM
WITH (
  kafka_topic = 'CNC_DATA',
  value_format = 'JSON'
) AS
SELECT * FROM FACTORY_ASSETS_STREAM
WHERE ASSET_UUID = 'CNC' OR ASSET_UUID = 'DUSTTRAK'
EMIT CHANGES;
```

## Lister les stream
```sh
SHOW STREAMS;
```

## Lister les infos d’un stream
```sh
DESCRIBE STREAM_NAME EXTENDED;
```

## Supprimer un stream
```sh
DROP STREAM_NAME;
```

## Lister les topics
```sh
SHOW TOPICS;
```

## Lister les informations détaillées d’un topic
```sh
docker exec broker kafka-topics --bootstrap-server broker:29092 --describe --topic "TOPIC_NAME"
```

## Lister les queries
```sh
SHOW QUERIES;
```

## Terminer une querry 
```sql
TERMINATE ID_TROUVE_AVEC_SHOW_QUERIES;
```

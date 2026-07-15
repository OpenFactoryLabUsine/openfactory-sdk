# Kafka
Explications : 
https://kafka.apache.org/43/getting-started/introduction/

Délais de rétention des données : 
https://medium.com/@chinthakadd/how-to-approach-kafka-retention-policy-configuration-as-an-application-developer-c7011d3c7d9f

## Lire les données du TOPIC kafka : 
```bash
docker exec -it broker kafka-console-consumer --bootstrap-server localhost:9092 --topic ASSETS --from-beginning
```

## Ajouter une période de rétention à un TOPIC

```sh
docker exec broker kafka-configs \
  --bootstrap-server broker:29092 \
  --entity-type topics \
  --entity-name ASSETS \
  --alter \
  --add-config retention.bytes=53687091200,cleanup.policy=delete
```

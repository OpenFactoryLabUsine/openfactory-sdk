#!/bin/bash

KSQL_URL="http://localhost:8088/ksql"

KSQL_STATEMENT=$(cat <<EOF
CREATE OR REPLACE STREAM CNC_DATA_STREAM
WITH (
  kafka_topic = 'CNC_DATA',
  value_format = 'JSON'
) AS
SELECT * FROM FACTORY_ASSETS_STREAM
WHERE ASSET_UUID = 'CNC' OR ASSET_UUID = 'DUSTTRAK'
EMIT CHANGES;
EOF
)

PAYLOAD=$(cat <<EOF
{
  "ksql": "${KSQL_STATEMENT}",
  "streamsProperties": {
    "ksql.streams.auto.offset.reset": "earliest"
  }
}
EOF
)

curl -s -X POST \
     -H "Content-Type: application/vnd.ksql.v1+json" \
     -d "$PAYLOAD" \
     "$KSQL_URL"

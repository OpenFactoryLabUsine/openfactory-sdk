#!/bin/bash
set -e
#
# spinup.sh - Start the OpenFactory stack inside the devcontainer
#
# This script will:
#   1. Start the Kafka cluster defined in docker-compose.yml
#   2. Setup required Kafka topics
#   3. Initialize the OpenFactory stream processing topology via ofa setup-kafka
#   4. Start the fan-out layer defined in docker-compose.fan-out-layer.yml
#
# Environment variables:
#   KSQLDB_URL - URL of the ksqlDB server (defaults set in install.sh profile script)
#
# Usage:
#   spinup.sh
#

echo "🚀  Starting OpenFactory stack..."

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/workspaces/openfactory-sdk}"
ENV_FILE="${WORKSPACE_ROOT}/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
else
  echo "No environment file found at ${ENV_FILE}; continuing without it."
fi

if [ -z "${KSQLDB_URL:-}" ]; then
  if [ -n "${CONTAINER_IP:-}" ]; then
    export KSQLDB_URL="http://${CONTAINER_IP}:8088"
  else
    export KSQLDB_URL="http://localhost:8088"
  fi
fi

COMPOSE_ENV_ARGS=()
if [ -f "$ENV_FILE" ]; then
  COMPOSE_ENV_ARGS+=(--env-file "$ENV_FILE")
fi

# Location of docker-compose file
SDK_PATH="/usr/local/share/openfactory-sdk"
KAFKA_COMPOSE_FILE="${SDK_PATH}/openfactory-infra/docker-compose.yml"
TRAEFIK_COMPOSE_FILE="${SDK_PATH}/openfactory-infra/docker-compose.traefik.yml"
FAN_OUT_LAYER_COMPOSE_FILE="${SDK_PATH}/openfactory-fanoutlayer/docker-compose.yml"
INFLUXDB_COMPOSE_FILE="${SDK_PATH}/openfactory-infra/docker-compose.influxdb.yml"

# Ensure InfluxDB can write its bind-mounted data directory.
INFLUXDB_DATA_DIR="/workspaces/openfactory-sdk/influxdb3/"
if [ ! -e "${INFLUXDB_DATA_DIR}" ]; then
  mkdir -p "${INFLUXDB_DATA_DIR}"
fi
sudo chown -R 1500:1500 "${INFLUXDB_DATA_DIR}"

# Ensure the Explorer UI can write its SQLite database.
INFLUX_EXPLORER_DB_DIR="/workspaces/openfactory-sdk/influxdb3-ui"
if [ ! -e "${INFLUX_EXPLORER_DB_DIR}" ]; then
  mkdir -p "${INFLUX_EXPLORER_DB_DIR}"
fi
sudo chown -R 1500:1500 "${INFLUX_EXPLORER_DB_DIR}"

FAN_OUT_LAYER_COMPOSE_FILE="${SDK_PATH}/openfactory-infra/docker-compose.nats.yml"
PROMETHEUS_COMPOSE_FILE="${SDK_PATH}/openfactory-infra/docker-compose.prometheus.yml"

# Spin up containers
echo "🐳  Deploying Kafka CLuster ..."
docker compose "${COMPOSE_ENV_ARGS[@]}" -f "${KAFKA_COMPOSE_FILE}" -p kafka-cluster up -d

# Setup Traefik
echo "🐳  Deploying Treafik ..."
docker compose "${COMPOSE_ENV_ARGS[@]}" -f "${TRAEFIK_COMPOSE_FILE}" -p traefik up -d

# Setup Prometheus
echo "🐳  Deploying Prometheus ..."
docker compose "${COMPOSE_ENV_ARGS[@]}" -f "${PROMETHEUS_COMPOSE_FILE}" -p prometheus up -d

# Setup InfluxDB
echo "🐳  Deploying InfluxDB ..."
docker compose "${COMPOSE_ENV_ARGS[@]}" -f "$INFLUXDB_COMPOSE_FILE" -p influxdb up -d

# Setup required Kafka topics
echo "⚙️  Setting up Kafka topics ..."
/usr/local/bin/create_topics.sh

# Wait for ksqlDB to be ready
echo "⏳ Waiting for ksqlDB to be ready..."
until $(curl --silent --fail --output /dev/null "${KSQLDB_URL}/info"); do
    printf '.'
    sleep 2
done
echo " ksqlDB is ready!"


# Run OpenFactory setup
echo "⚙️  Deploying OpenFactory stream processing topology ..."
ofa setup-kafka --ksqldb-server "${KSQLDB_URL}"


# Setup OpenFactory Fan-out Layer
echo "🐳  Deploying OpenFactory fan-out layer ..."
docker compose "${COMPOSE_ENV_ARGS[@]}" -f "$FAN_OUT_LAYER_COMPOSE_FILE" -p fan-out-layer up -d --scale asset-router=1

# Setup OpenFactory Monitoring Layer
echo "🏭 Deploying OpenFactory monitoring layer ..."
ofa apps up ${SDK_PATH}/openfactory-infra/monitoring/

# Setup OpenFactory Asset Forwarder
echo "🏭 Deploying OpenFactory asset forwarder ..."
ofa apps up ${SDK_PATH}/openfactory-infra/fanoutlayer

echo "✅  OpenFactory stack is ready!"

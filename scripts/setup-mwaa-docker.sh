#!/bin/bash
set -e

# Simple script to setup MWAA Docker environment

VERSION=""
MWAA_REPO="https://github.com/aws/amazon-mwaa-docker-images.git"
MWAA_DIR=".mwaa-docker"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$VERSION" ]; then
    echo "Error: --version is required"
    exit 1
fi

echo "Setting up MWAA Docker environment for Airflow ${VERSION}"

# Clone MWAA Docker images repo if not exists
if [ ! -d "$MWAA_DIR" ]; then
    echo "Cloning MWAA Docker images repository..."
    git clone --depth 1 "$MWAA_REPO" "$MWAA_DIR"
else
    echo "MWAA Docker repository already exists, pulling latest..."
    cd "$MWAA_DIR" && git pull && cd ..
fi

# Check if version exists
if [ ! -d "$MWAA_DIR/images/airflow/${VERSION}" ]; then
    echo "Error: Airflow version ${VERSION} not found in MWAA repository"
    echo "Available versions:"
    ls "$MWAA_DIR/images/airflow/" | grep -E '^[0-9]+\.'
    exit 1
fi

# Build the Docker image
echo "Building MWAA Docker image for Airflow ${VERSION}..."
cd "$MWAA_DIR/images/airflow/${VERSION}"

# Create a simple docker-compose for CI
cat > docker-compose.ci.yml << EOF
version: '3.8'

services:
  airflow:
    build:
      context: .
      dockerfile: Dockerfile
    image: mwaa-local:${VERSION}
    container_name: airflow-ci-${VERSION}
    environment:
      - AIRFLOW__CORE__EXECUTOR=LocalExecutor
      - AIRFLOW__CORE__LOAD_EXAMPLES=False
      - AIRFLOW__CORE__LOAD_DEFAULT_CONNECTIONS=False
      - AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=sqlite:////usr/local/airflow/airflow.db
      - AIRFLOW_HOME=/usr/local/airflow
      - PYTHONPATH=/usr/local/airflow/dags
    volumes:
      - airflow-db:/usr/local/airflow
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "airflow", "db", "check"]
      interval: 10s
      timeout: 10s
      retries: 5
    command: >
      bash -c "airflow db init &&
               airflow users create --username admin --password admin --firstname Admin --lastname User --role Admin --email admin@example.com || true &&
               tail -f /dev/null"

volumes:
  airflow-db:
EOF

# Build the image
docker-compose -f docker-compose.ci.yml build

echo "MWAA Docker setup completed successfully"
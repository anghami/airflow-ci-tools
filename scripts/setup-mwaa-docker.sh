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

# Use the existing docker-compose.yaml that comes with MWAA
if [ -f "docker-compose.yaml" ]; then
    echo "Using MWAA's docker-compose.yaml to build the image..."
    # Build using the existing MWAA docker-compose
    docker-compose build

    # Tag the image for our use (MWAA uses local-runner as image name)
    echo "Tagging image as mwaa-local:${VERSION}..."
    docker tag local-runner:latest-amd64 mwaa-local:${VERSION} 2>/dev/null || \
    docker tag local-runner:latest mwaa-local:${VERSION} 2>/dev/null || \
    echo "Note: Image might already be tagged or have different architecture tag"
else
    echo "Error: docker-compose.yaml not found in MWAA directory"
    echo "Available files:"
    ls -la
    exit 1
fi

echo "MWAA Docker setup completed successfully"
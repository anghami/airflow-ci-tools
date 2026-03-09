#!/bin/bash
set -e

# Install additional requirements in MWAA Docker image

VERSION=""
REQUIREMENTS=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift ;;
        --requirements) REQUIREMENTS="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$VERSION" ] || [ -z "$REQUIREMENTS" ]; then
    echo "Error: --version and --requirements are required"
    exit 1
fi

if [ ! -f "$REQUIREMENTS" ]; then
    echo "Error: Requirements file not found: $REQUIREMENTS"
    exit 1
fi

echo "Installing requirements for Airflow ${VERSION}"
echo "Requirements file: ${REQUIREMENTS}"

# Create a Dockerfile that extends Apache Airflow image with requirements
cat > /tmp/Dockerfile.requirements << EOF
FROM apache/airflow:${VERSION}-python3.11

# Switch to root to install packages
USER root

# Copy requirements file
COPY $(basename ${REQUIREMENTS}) /tmp/requirements.txt

# Install requirements
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Clean up and switch back to airflow user
RUN rm /tmp/requirements.txt
USER airflow
EOF

# Build extended image with Apache Airflow base
cp "${REQUIREMENTS}" /tmp/$(basename ${REQUIREMENTS})
docker build -t apache/airflow:${VERSION}-python3.11 -f /tmp/Dockerfile.requirements /tmp/

echo "Requirements installed successfully"
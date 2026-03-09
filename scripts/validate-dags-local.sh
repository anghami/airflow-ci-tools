#!/bin/bash
# Local validation script for developers

set -e

VERSION="${AIRFLOW_VERSION:-2.9.2}"
DAGS_PATH="${1:-./dags}"

echo "🚀 Airflow CI Tools - Local DAG Validator"
echo "=========================================="
echo "Airflow Version: ${VERSION}"
echo "DAGs Path: ${DAGS_PATH}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running"
    echo "Please start Docker and try again"
    exit 1
fi

# Check if DAGs path exists
if [ ! -d "$DAGS_PATH" ]; then
    echo "❌ Error: DAGs path not found: ${DAGS_PATH}"
    exit 1
fi

# Setup MWAA Docker
echo "📦 Setting up MWAA Docker environment..."
./scripts/setup-mwaa-docker.sh --version ${VERSION}

# Validate DAG imports
echo ""
echo "🔍 Validating DAG imports..."
./scripts/validate-dag-imports.sh --version ${VERSION} --dags-path ${DAGS_PATH}

# Run DAG tests
echo ""
echo "🧪 Running DAG tests..."
./scripts/run-dag-tests.sh --version ${VERSION} --dags-path ${DAGS_PATH}

echo ""
echo "✅ All validations passed!"
#!/bin/bash
set -e

# Simple DAG testing script using Airflow CLI

VERSION=""
DAGS_PATH=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift ;;
        --dags-path) DAGS_PATH="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$VERSION" ] || [ -z "$DAGS_PATH" ]; then
    echo "Error: --version and --dags-path are required"
    exit 1
fi

echo "Running DAG tests for Airflow ${VERSION}"
echo "DAGs path: ${DAGS_PATH}"

# Prepare environment variables
ENV_VARS=""
if [ -f ".env.custom" ]; then
    ENV_VARS="--env-file $(pwd)/.env.custom"
fi

# Start Airflow container
echo "Starting Airflow container..."
docker run -d \
    --name airflow-test-${VERSION} \
    -v "${DAGS_PATH}:/usr/local/airflow/dags:ro" \
    -e AIRFLOW__CORE__LOAD_EXAMPLES=False \
    -e AIRFLOW__CORE__EXECUTOR=LocalExecutor \
    -e AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=sqlite:////usr/local/airflow/airflow.db \
    -e AIRFLOW_HOME=/usr/local/airflow \
    -e PYTHONPATH=/usr/local/airflow/dags \
    ${ENV_VARS} \
    mwaa-local:${VERSION} \
    bash -c "airflow db init && tail -f /dev/null"

# Wait for container to be ready
echo "Waiting for Airflow to initialize..."
sleep 10

# Function to run command in container
run_in_container() {
    docker exec airflow-test-${VERSION} "$@"
}

# Initialize database
echo "Initializing Airflow database..."
run_in_container airflow db init || true

# List all DAGs
echo -e "\n📋 Listing all DAGs:"
run_in_container airflow dags list

# Test each DAG parsing
echo -e "\n🧪 Testing DAG parsing:"
run_in_container airflow dags list-import-errors

# Get list of DAGs and test each one
echo -e "\n🔍 Running individual DAG tests:"
DAG_IDS=$(run_in_container airflow dags list -o plain | tail -n +2 | awk '{print $1}')

FAILED_DAGS=""
for dag_id in $DAG_IDS; do
    echo -n "Testing ${dag_id}... "
    if run_in_container airflow dags test ${dag_id} 2024-01-01 > logs/test_${dag_id}.log 2>&1; then
        echo "✅ PASSED"
    else
        echo "❌ FAILED (see logs/test_${dag_id}.log)"
        FAILED_DAGS="${FAILED_DAGS} ${dag_id}"
    fi
done

# Generate test report
echo -e "\n📊 Generating test report..."
cat > validation-results/test_report.txt << EOF
Airflow DAG Test Report
========================
Date: $(date)
Airflow Version: ${VERSION}
DAGs Path: ${DAGS_PATH}

Test Results:
EOF

if [ -z "$FAILED_DAGS" ]; then
    echo "✅ All DAGs passed testing" >> validation-results/test_report.txt
    EXIT_CODE=0
else
    echo "❌ Failed DAGs:${FAILED_DAGS}" >> validation-results/test_report.txt
    EXIT_CODE=1
fi

# Cleanup
echo "Cleaning up..."
docker stop airflow-test-${VERSION} > /dev/null 2>&1
docker rm airflow-test-${VERSION} > /dev/null 2>&1

echo -e "\nTest report saved to validation-results/test_report.txt"
exit $EXIT_CODE
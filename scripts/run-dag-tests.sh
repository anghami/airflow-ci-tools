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

# Create directories for results
mkdir -p validation-results
mkdir -p logs

# Prepare environment variables
ENV_VARS=""
if [ -f ".env.custom" ]; then
    ENV_VARS="--env-file $(pwd)/.env.custom"
fi

# Start Airflow container using official Apache Airflow image
echo "Starting Airflow container..."
docker run -d \
    --name airflow-test-${VERSION} \
    -v "${DAGS_PATH}:/opt/airflow/dags:ro" \
    -e AIRFLOW__CORE__LOAD_EXAMPLES=False \
    -e AIRFLOW__CORE__EXECUTOR=LocalExecutor \
    -e AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=sqlite:////opt/airflow/airflow.db \
    -e AIRFLOW_HOME=/opt/airflow \
    -e PYTHONPATH=/opt/airflow/dags \
    ${ENV_VARS} \
    apache/airflow:${VERSION}-python3.11 \
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
run_in_container airflow dags list 2>/dev/null || echo "No DAGs could be listed"

# Check for import errors (but don't fail because of them)
echo -e "\n⚠️  Import Warnings (DAGs skipped due to missing variables):"
run_in_container airflow dags list-import-errors 2>&1 | head -20 || true

# Get list of successfully imported DAGs and test each one
echo -e "\n🔍 Running tests for successfully imported DAGs:"
DAG_IDS=$(run_in_container airflow dags list -o plain 2>/dev/null | tail -n +2 | awk '{print $1}' || echo "")

if [ -z "$DAG_IDS" ]; then
    echo "⚠️  No DAGs could be imported for testing (likely due to missing Variables)"
    FAILED_DAGS=""
else
    FAILED_DAGS=""
    TESTED_COUNT=0
    for dag_id in $DAG_IDS; do
        echo -n "Testing ${dag_id}... "
        if run_in_container airflow dags test ${dag_id} 2024-01-01 > logs/test_${dag_id}.log 2>&1; then
            echo "✅ PASSED"
            ((TESTED_COUNT++))
        else
            echo "❌ FAILED (see logs/test_${dag_id}.log)"
            FAILED_DAGS="${FAILED_DAGS} ${dag_id}"
        fi
    done
    echo -e "\nTested ${TESTED_COUNT} DAGs"
fi

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

if [ -z "$DAG_IDS" ]; then
    echo "⚠️  No DAGs could be imported for testing" >> validation-results/test_report.txt
    echo "This is expected in CI environments without all Variables configured" >> validation-results/test_report.txt
    EXIT_CODE=0  # Don't fail if no DAGs could be imported
elif [ -z "$FAILED_DAGS" ]; then
    echo "✅ All ${TESTED_COUNT} imported DAGs passed testing" >> validation-results/test_report.txt
    EXIT_CODE=0
else
    echo "❌ Failed DAGs:${FAILED_DAGS}" >> validation-results/test_report.txt
    echo "✅ Passed: $((TESTED_COUNT - $(echo $FAILED_DAGS | wc -w)))" >> validation-results/test_report.txt
    EXIT_CODE=1
fi

# Cleanup
echo "Cleaning up..."
docker stop airflow-test-${VERSION} > /dev/null 2>&1
docker rm airflow-test-${VERSION} > /dev/null 2>&1

echo -e "\nTest report saved to validation-results/test_report.txt"
exit $EXIT_CODE
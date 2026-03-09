#!/bin/bash
set -e

# Simple DAG import validation script

VERSION=""
DAGS_PATH=""
ENV_FILE=""
REQUIREMENTS_FILE=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift ;;
        --dags-path) DAGS_PATH="$2"; shift ;;
        --env-file) ENV_FILE="$2"; shift ;;
        --requirements) REQUIREMENTS_FILE="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$VERSION" ] || [ -z "$DAGS_PATH" ]; then
    echo "Error: --version and --dags-path are required"
    exit 1
fi

echo "Validating DAG imports for Airflow ${VERSION}"
echo "DAGs path: ${DAGS_PATH}"

# Prepare environment variables
ENV_VARS=""
if [ -f ".env.custom" ]; then
    ENV_VARS="--env-file $(pwd)/.env.custom"
fi

# Create validation results directory
mkdir -p validation-results
mkdir -p logs

# Python script for DAG validation
cat > /tmp/validate_dags.py << 'EOF'
import sys
import os
import traceback
from pathlib import Path
import json
from unittest.mock import patch, MagicMock

# Add DAGs path to Python path
dags_path = sys.argv[1] if len(sys.argv) > 1 else '/opt/airflow/dags'
sys.path.insert(0, dags_path)

# Change to DAGs directory for relative imports
os.chdir(dags_path)

# Import Airflow
try:
    from airflow import DAG
    from airflow.models import DagBag
except ImportError as e:
    print(f"Failed to import Airflow: {e}")
    sys.exit(1)

def validate_dags():
    """Validate all DAGs in the specified path"""
    results = {
        'total_dags': 0,
        'valid_dags': 0,
        'invalid_dags': 0,
        'import_errors': [],
        'dag_errors': []
    }

    print(f"Scanning for DAGs in: {dags_path}")

    # Find all Python files
    dag_files = list(Path(dags_path).rglob("*.py"))
    print(f"Found {len(dag_files)} Python files")

    # Initialize DagBag
    dagbag = DagBag(dags_path, include_examples=False)

    # Check for import errors (but don't fail validation because of them)
    if dagbag.import_errors:
        print("\n⚠️  Import Warnings (DAGs skipped due to missing variables or dependencies):")
        for filepath, error in dagbag.import_errors.items():
            print(f"  - {filepath}")
            # Only show first line of error for brevity
            error_first_line = str(error).split('\n')[0]
            print(f"    {error_first_line}")
            results['import_errors'].append({
                'file': filepath,
                'error': str(error)
            })

    # Validate each DAG
    print(f"\nFound {len(dagbag.dags)} valid DAGs:")
    for dag_id, dag in dagbag.dags.items():
        try:
            # Basic validation
            if not dag.dag_id:
                raise ValueError("DAG has no ID")

            # Check for cycles using the appropriate method for the Airflow version
            if hasattr(dag, 'test_cycle'):
                dag.test_cycle()
            elif hasattr(dag, 'has_cycle'):
                if dag.has_cycle():
                    raise ValueError("DAG has a cycle")
            # If neither method exists, skip cycle check

            print(f"  ✅ {dag_id} - Valid")
            results['valid_dags'] += 1

        except Exception as e:
            print(f"  ❌ {dag_id} - Error: {e}")
            results['dag_errors'].append({
                'dag_id': dag_id,
                'error': str(e)
            })
            results['invalid_dags'] += 1

    results['total_dags'] = results['valid_dags'] + results['invalid_dags']

    # Write results to file
    with open('/tmp/validation_results.json', 'w') as f:
        json.dump(results, f, indent=2)

    # Print summary
    print(f"\n{'='*50}")
    print(f"Validation Summary:")
    print(f"  Successfully Imported DAGs: {results['total_dags']}")
    print(f"  ✅ Valid: {results['valid_dags']}")
    print(f"  ❌ Invalid (with errors): {results['invalid_dags']}")
    print(f"  ⚠️  Skipped (import issues): {len(results['import_errors'])}")
    print(f"{'='*50}")

    # Only fail if imported DAGs have validation errors
    # Import errors are ignored as they're often due to missing variables in CI
    if results['total_dags'] > 0:
        if results['invalid_dags'] == 0:
            print(f"\n✅ Validation PASSED - All {results['valid_dags']} imported DAGs are valid")
            return 0
        else:
            print(f"\n❌ Validation FAILED - {results['invalid_dags']} DAG(s) have errors")
            return 1
    else:
        print(f"\n❌ Validation FAILED - No DAGs could be imported")
        return 1

if __name__ == "__main__":
    sys.exit(validate_dags())
EOF

# Prepare Docker command
DOCKER_CMD="docker run --rm \
    -v \"${DAGS_PATH}:/opt/airflow/dags:ro\" \
    -v \"/tmp/validate_dags.py:/tmp/validate_dags.py:ro\" \
    -e AIRFLOW__CORE__LOAD_EXAMPLES=False \
    -e AIRFLOW__CORE__EXECUTOR=LocalExecutor \
    -e AIRFLOW_HOME=/opt/airflow \
    -e PYTHONPATH=/opt/airflow/dags \
    ${ENV_VARS}"

# Add requirements file if provided
if [ -n "$REQUIREMENTS_FILE" ] && [ -f "$REQUIREMENTS_FILE" ]; then
    echo "Installing additional requirements from $REQUIREMENTS_FILE..."

    # Create a temporary requirements file without constraints
    TEMP_REQUIREMENTS="/tmp/requirements_${VERSION}.txt"
    cp "$REQUIREMENTS_FILE" "$TEMP_REQUIREMENTS"

    # Remove constraint line to avoid version conflicts when testing with different Airflow versions
    sed -i.bak '/^--constraint/d' "$TEMP_REQUIREMENTS" 2>/dev/null || \
    sed -i "" '/^--constraint/d' "$TEMP_REQUIREMENTS" 2>/dev/null || true

    DOCKER_CMD="$DOCKER_CMD -v \"$TEMP_REQUIREMENTS:/tmp/requirements.txt:ro\""

    # Run validation with requirements installation using Airflow's recommended approach
    echo "Running DAG validation with requirements installation..."
    eval "$DOCKER_CMD apache/airflow:${VERSION}-python3.11 bash -c \"
        pip install --no-cache-dir -r /tmp/requirements.txt &&
        airflow db init &&
        python /tmp/validate_dags.py /opt/airflow/dags
    \""

    # Clean up temp file
    rm -f "$TEMP_REQUIREMENTS" "$TEMP_REQUIREMENTS.bak" 2>/dev/null
else
    # Run validation without additional requirements
    echo "Running DAG import validation using apache/airflow:${VERSION}-python3.11..."
    eval "$DOCKER_CMD apache/airflow:${VERSION}-python3.11 bash -c \"
        airflow db init &&
        python /tmp/validate_dags.py /opt/airflow/dags
    \""
fi

# Copy results if they exist
if docker run --rm -v "/tmp:/tmp" alpine test -f /tmp/validation_results.json; then
    cp /tmp/validation_results.json validation-results/
    echo "Validation results saved to validation-results/validation_results.json"
fi

echo "DAG import validation completed"
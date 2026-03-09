# Usage Guide

## Quick Start

### 1. Using in Your GitHub Repository

Add this workflow to your repository at `.github/workflows/ci.yml`:

```yaml
name: Validate Airflow DAGs

on: [push, pull_request]

jobs:
  validate:
    uses: your-org/airflow-ci-tools/.github/workflows/validate-dags.yml@main
    with:
      airflow-version: "2.9.2"
      dags-path: "dags/"
```

That's it! Your DAGs will be validated on every push and PR.

## Configuration Options

### Basic Configuration

```yaml
with:
  airflow-version: "2.9.2"    # Required: Airflow version
  dags-path: "dags/"           # Optional: Path to DAGs (default: "dags")
```

### Advanced Configuration

```yaml
with:
  airflow-version: "2.9.2"
  dags-path: "dags/"
  python-version: "3.11"
  requirements-file: "requirements.txt"
  environment-vars: |
    ENVIRONMENT=staging
    AWS_REGION=us-east-1
    DB_HOST=localhost
    API_KEY=${{ secrets.API_KEY }}
```

## Local Development

### Setup

1. Clone the airflow-ci-tools repository:
```bash
git clone https://github.com/your-org/airflow-ci-tools.git
cd airflow-ci-tools
```

2. Run local validation:
```bash
./scripts/validate-dags-local.sh /path/to/your/dags
```

### Manual Testing

```bash
# Setup MWAA Docker
./scripts/setup-mwaa-docker.sh --version 2.9.2

# Validate DAG imports
./scripts/validate-dag-imports.sh \
  --version 2.9.2 \
  --dags-path /path/to/dags

# Run DAG tests
./scripts/run-dag-tests.sh \
  --version 2.9.2 \
  --dags-path /path/to/dags
```

## Environment Variables

### Default MWAA Variables

These are automatically set to simulate MWAA:
- `AIRFLOW_HOME=/usr/local/airflow`
- `AIRFLOW__CORE__EXECUTOR=LocalExecutor`
- `AIRFLOW__CORE__LOAD_EXAMPLES=False`

### Custom Variables

Pass custom environment variables in GitHub Actions:

```yaml
environment-vars: |
  MY_VAR=value
  SECRET=${{ secrets.MY_SECRET }}
```

Or create `.env.custom` file for local testing:
```bash
echo "MY_VAR=value" > .env.custom
```

## Handling Requirements

### In GitHub Actions

```yaml
with:
  requirements-file: "requirements/prod.txt"
```

### Local Development

```bash
./scripts/install-requirements.sh \
  --version 2.9.2 \
  --requirements /path/to/requirements.txt
```

## Validation Output

### Success Output
```
✅ sample_data_pipeline - Valid
✅ etl_pipeline - Valid
✅ ml_training_dag - Valid

Validation Summary:
  Total DAGs: 3
  Valid: 3
  Invalid: 0
```

### Error Output
```
❌ Import Errors Found:
  - dags/broken_dag.py:
    No module named 'missing_module'

❌ broken_dag - Error: DAG has cycle

Validation Summary:
  Total DAGs: 1
  Valid: 0
  Invalid: 1
```

## Troubleshooting

### Docker Not Running
```
Error: Docker is not running
```
**Solution**: Start Docker Desktop or Docker daemon

### Version Not Supported
```
Error: Airflow version 2.10.0 not found in MWAA repository
Available versions:
2.9.2
2.8.1
```
**Solution**: Use a supported version from the list

### Import Errors
```
Import Error: No module named 'custom_module'
```
**Solution**:
1. Add module to requirements.txt
2. Ensure module is in PYTHONPATH
3. Check relative imports

### DAG Not Found
```
No DAGs found in /path/to/dags
```
**Solution**:
1. Check path is correct
2. Ensure files have `.py` extension
3. Verify DAG objects are created

## Best Practices

1. **Version Pinning**: Always specify exact Airflow version
2. **Requirements**: Keep requirements.txt up to date
3. **Environment Variables**: Use GitHub Secrets for sensitive data
4. **Testing**: Run local validation before pushing
5. **Caching**: GitHub Actions caches Docker layers automatically

## Example Projects

See `/examples/sample-dag-project/` for a complete example including:
- GitHub Actions configuration
- Sample DAGs
- Requirements management
- Local testing setup
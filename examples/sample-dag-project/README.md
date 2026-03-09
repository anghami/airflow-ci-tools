# Sample DAG Project

Example Airflow DAG project using airflow-ci-tools for CI/CD.

## Structure

```
sample-dag-project/
├── .github/workflows/ci.yml  # CI pipeline configuration
├── dags/                      # Airflow DAG definitions
│   └── sample_dag.py
├── requirements.txt           # Python dependencies
└── README.md
```

## CI/CD Integration

This project uses the `airflow-ci-tools` repository for CI/CD:

1. **Automatic Validation**: Every push and PR triggers DAG validation
2. **MWAA Environment**: Uses official AWS MWAA Docker images
3. **Import Testing**: Validates all DAG imports
4. **Syntax Checking**: Ensures Python syntax is correct

## Local Testing

```bash
# Clone airflow-ci-tools
git clone https://github.com/your-org/airflow-ci-tools.git

# Run validation locally
cd airflow-ci-tools
./scripts/setup-mwaa-docker.sh --version 2.9.2
./scripts/validate-dag-imports.sh --version 2.9.2 --dags-path ../sample-dag-project/dags
```

## GitHub Actions

The CI pipeline automatically runs on:
- Push to main or develop branches
- Pull requests to main branch

See `.github/workflows/ci.yml` for configuration.
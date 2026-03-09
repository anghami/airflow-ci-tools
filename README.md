# Airflow CI Tools

Simple, reusable CI/CD tooling for Apache Airflow DAG projects deployed on AWS MWAA.

## Quick Start

Use this repository in your GitHub Actions:

```yaml
name: Validate DAGs

on: [push, pull_request]

jobs:
  validate:
    uses: your-org/airflow-ci-tools/.github/workflows/validate-dags.yml@main
    with:
      airflow-version: "2.9.2"
      dags-path: "dags/"
```

## Features

- ✅ Uses official AWS MWAA Docker images
- ✅ Validates DAG imports and syntax
- ✅ Simulates MWAA environment
- ✅ Supports multiple Airflow versions
- ✅ Simple bash/Python scripts
- ✅ Reusable GitHub Actions

## Repository Structure

```
airflow-ci-tools/
├── .github/workflows/        # Reusable GitHub Actions
├── docker/                   # Docker setup files
├── scripts/                  # Validation and test scripts
├── config/                   # Environment configurations
└── examples/                 # Example DAG projects
```

## Supported Airflow Versions

- 2.9.2
- 2.8.1
- 2.7.3
- 2.6.3

## Usage

### In GitHub Actions

```yaml
uses: your-org/airflow-ci-tools/.github/workflows/validate-dags.yml@main
with:
  airflow-version: "2.9.2"
  dags-path: "dags/"
  python-version: "3.11"
  environment-vars: |
    ENVIRONMENT=dev
    AWS_REGION=us-east-1
```

### Local Testing

```bash
# Clone this repository
git clone https://github.com/your-org/airflow-ci-tools.git

# Run validation
./scripts/validate-dags.sh --airflow-version 2.9.2 --dags-path /path/to/dags
```

## Requirements

- Docker
- Bash
- Python 3.8+
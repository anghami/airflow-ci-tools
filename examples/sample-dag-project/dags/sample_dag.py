"""
Sample DAG demonstrating CI/CD integration
"""
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator

default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

def process_data(**context):
    """Sample data processing function"""
    execution_date = context['execution_date']
    print(f"Processing data for {execution_date}")
    return "Data processed successfully"

with DAG(
    'sample_data_pipeline',
    default_args=default_args,
    description='Sample data processing pipeline',
    schedule_interval='@daily',
    catchup=False,
    tags=['sample', 'data-pipeline'],
) as dag:

    start_task = BashOperator(
        task_id='start',
        bash_command='echo "Starting pipeline run"',
    )

    process_task = PythonOperator(
        task_id='process_data',
        python_callable=process_data,
    )

    end_task = BashOperator(
        task_id='end',
        bash_command='echo "Pipeline completed"',
    )

    start_task >> process_task >> end_task
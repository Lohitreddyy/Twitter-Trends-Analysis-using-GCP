# Dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY ./requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY ./data_ingestion/twitter_to_pubsub.py .

ENV GOOGLE_APPLICATION_CREDENTIALS="/app/creds.json"
COPY ./creds.json /app/creds.json  # Add service account key here

CMD ["python", "twitter_to_pubsub.py"]


terraform/
  ├── main.tf
  ├── variables.tf
  ├── outputs.tf

  #main.tf
  provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_pubsub_topic" "twitter" {
  name = "twitter-topic"
}

resource "google_bigquery_dataset" "twitter_data" {
  dataset_id = "twitter_dataset"
  location   = var.region
}

resource "google_bigquery_table" "tweets" {
  dataset_id = google_bigquery_dataset.twitter_data.dataset_id
  table_id   = "tweets"
  schema     = file("schema.json")
}

#variables.tf
variable "project_id" {}
variable "region" {
  default = "us-central1"
}

#schema.json
[
  {"name": "id", "type": "INTEGER", "mode": "REQUIRED"},
  {"name": "text", "type": "STRING", "mode": "REQUIRED"},
  {"name": "created_at", "type": "TIMESTAMP", "mode": "REQUIRED"},
  {"name": "sentiment", "type": "FLOAT", "mode": "NULLABLE"}
]



#k8s/twitter-ingest.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: twitter-ingest
spec:
  replicas: 1
  selector:
    matchLabels:
      app: twitter-ingest
  template:
    metadata:
      labels:
        app: twitter-ingest
    spec:
      containers:
      - name: tweet-collector
        image: gcr.io/YOUR_PROJECT_ID/twitter-ingest:latest
        env:
        - name: TWITTER_BEARER_TOKEN
          valueFrom:
            secretKeyRef:
              name: twitter-secrets
              key: bearer_token
        - name: GOOGLE_APPLICATION_CREDENTIALS
          value: /app/creds.json
        volumeMounts:
        - name: gcp-creds
          mountPath: /app/creds.json
          subPath: creds.json
      volumes:
      - name: gcp-creds
        secret:
          secretName: gcp-credentials

  

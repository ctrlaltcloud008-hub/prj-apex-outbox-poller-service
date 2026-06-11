# --- Variables ---

project_id  := "apex-494315"
region      := "asia-south1"
registry    := "asia-south1-docker.pkg.dev"
repo        := "prj-apex-artifact-registry"
service     := "outbox-relay"
sa          := "ci-cd-98@apex-494315.iam.gserviceaccount.com"
image       := registry + "/" + project_id + "/" + repo + "/relay"
git_sha     := `git rev-parse --short HEAD`

spanner_db  := "projects/apex-494315/instances/apex-spanner-instance/databases/apex-database"

# --- Local Dev ---

spanner-up:
  docker run --name spanner-emulator --network spanner-net \
    -p 9010:9010 -p 9020:9020 -d \
    gcr.io/cloud-spanner-emulator/emulator

emulator-config:
  gcloud config configurations create emulator 2>/dev/null || true
  gcloud config configurations activate emulator
  gcloud config set auth/disable_credentials true
  gcloud config set project test-project
  gcloud config set api_endpoint_overrides/spanner http://localhost:9020/

spanner-create:
  gcloud spanner instances create test-instance \
    --config=regional-us-central1 \
    --description="Local Instance" \
    --nodes=1
  gcloud spanner databases create test-database --instance test-instance

spanner-cli:
  SPANNER_EMULATOR_HOST=localhost:9010 spanner-cli sql \
    --project test-project \
    --instance test-instance \
    --database test-database

pubsub-up:
  gcloud beta emulators pubsub start \
    --project=test-project \
    --host-port=0.0.0.0:8085 &
  sleep 2
  echo "Pub/Sub emulator ready on 0.0.0.0:8085"

pubsub-init:
  curl -X PUT http://localhost:8085/v1/projects/test-project/topics/video.received
  curl -X PUT http://localhost:8085/v1/projects/test-project/subscriptions/test-subscription \
    -H "Content-Type: application/json" \
    -d '{"topic": "projects/test-project/topics/video.received"}'

pubsub-down:
  lsof -ti tcp:8085 | xargs kill -9 2>/dev/null; true

run:
  docker run -d \
    -v $HOME/.config/gcloud:/tmp/gcloud:ro \
    -e GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcloud/application_default_credentials.json \
    -e OTEL_RESOURCE_ATTRIBUTES="gcp.project_id={{project_id}}" \
    -e OTEL_EXPORTER_OTLP_ENDPOINT=https://telemetry.googleapis.com \
    -e GOOGLE_CLOUD_QUOTA_PROJECT="{{project_id}}" \
    --name prj-apex-outbox-relay-service \
    --network spanner-net \
    -p 8080:8080 \
    -e SPANNER_EMULATOR_HOST=spanner-emulator:9010 \
    -e PUBSUB_EMULATOR_HOST=host.docker.internal:8085 \
    -e APP_ENV=local \
    prj-apex-outbox-relay-service

# --- Build & Push ---

docker-auth:
  gcloud auth configure-docker {{registry}}

build:
  docker buildx build --platform=linux/amd64 --load \
    -t prj-apex-outbox-relay-service \
    .

push:
  docker buildx build --platform=linux/amd64 --no-cache --push \
    -t {{image}}:{{git_sha}} \
    -t {{image}}:latest \
    .

# --- Cloud Run Deploy (temporary — migrate to GKE later) ---

deploy: push
  gcloud run deploy {{service}} \
    --image={{image}}:{{git_sha}} \
    --region={{region}} \
    --platform=managed \
    --no-allow-unauthenticated \
    --service-account={{sa}} \
    --memory=512Mi --cpu=1 \
    --min-instances=1 --max-instances=3 \
    --concurrency=1 --timeout=300 \
    --clear-secrets \
    --set-env-vars="APP_ENV=development,SERVICE={{service}},REGION={{region}},PROJECT_ID={{project_id}},SPANNER_DATABASE={{spanner_db}},CHANGE_STREAM_NAME=outbox_stream,HEARTBEAT_INTERVAL_MS=10000,START_LOOKBACK_SECONDS=1200,OTEL_RESOURCE_ATTRIBUTES=gcp.project_id={{project_id}},OTEL_EXPORTER_OTLP_ENDPOINT=https://telemetry.googleapis.com,GOOGLE_CLOUD_QUOTA_PROJECT={{project_id}}"

# --- Database ---

migrate-up:
  export SPANNER_EMULATOR_HOST=localhost:9010 && \
  export SPANNER_PROJECT_ID=test-project && \
  export SPANNER_INSTANCE_ID=test-instance && \
  export SPANNER_DATABASE_ID=test-database && \
  wrench migrate up --directory schema

migrate-gcp:
  wrench migrate up \
    --project {{project_id}} \
    --instance apex-spanner-instance \
    --database apex-database \
    --directory schema

# --- Code Quality ---

fmt:
  go fmt ./...

vet:
  go vet ./...

lint:
  golangci-lint run

test:
  go test ./... -v

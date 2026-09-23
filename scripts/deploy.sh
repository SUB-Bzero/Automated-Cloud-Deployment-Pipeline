#!/usr/bin/env bash
####################################################################
# deploy.sh — runs on the EC2 host (user: ubuntu).
#
#   deploy.sh <image-tag>   deploy a specific image tag from ECR
#   deploy.sh latest        deploy the "latest" tag
#   deploy.sh previous      roll back to the previously deployed tag
#
# The script:
#   1. logs in to ECR using the instance role (no static credentials),
#   2. pulls the requested image,
#   3. swaps the running container (recording tags for rollback),
#   4. reads the RDS connection string from SSM Parameter Store,
#   5. waits for /health to return 200 and reports success/failure.
####################################################################
set -euo pipefail

IMAGE_TAG="${1:-latest}"
CONFIG_FILE="/etc/acdp/env"
CONTAINER_NAME="acdp-app"
STATE_DIR="/opt/acdp"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: $CONFIG_FILE not found. Was the instance bootstrapped by Terraform user_data?" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG_FILE"

mkdir -p "$STATE_DIR"
CURRENT_TAG="$(cat "$STATE_DIR/current_tag" 2>/dev/null || echo "")"
PREVIOUS_TAG="$(cat "$STATE_DIR/previous_tag" 2>/dev/null || echo "")"

# Translate the rollback alias.
if [ "$IMAGE_TAG" = "previous" ]; then
  if [ -z "$PREVIOUS_TAG" ]; then
    echo "ERROR: no previous image tag recorded — nothing to roll back to." >&2
    exit 1
  fi
  echo "Rolling back: $CURRENT_TAG -> $PREVIOUS_TAG"
  IMAGE_TAG="$PREVIOUS_TAG"
fi

echo "Deploying ${ECR_REPOSITORY_URL}:${IMAGE_TAG}"

# 1. ECR login via instance role (no credentials stored on the host).
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "${ECR_REPOSITORY_URL%%/*}"

# 2. Pull the requested image.
if ! docker pull "${ECR_REPOSITORY_URL}:${IMAGE_TAG}"; then
  echo "ERROR: unable to pull ${ECR_REPOSITORY_URL}:${IMAGE_TAG}" >&2
  exit 1
fi

# 3. Swap the container.
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  docker rm -f "$CONTAINER_NAME"
fi

# 4. Fetch the RDS connection string from SSM Parameter Store (SecureString).
DATABASE_URL="$(aws ssm get-parameter \
  --name "$DB_PARAMETER_NAME" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text \
  --region "$AWS_REGION")"

docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p "${APP_PORT}:${APP_PORT}" \
  -e DATABASE_URL \
  -e APP_VERSION="$IMAGE_TAG" \
  -e NODE_ENV=production \
  "${ECR_REPOSITORY_URL}:${IMAGE_TAG}"

# 5. Record tags so we can roll back later.
if [ -n "$CURRENT_TAG" ] && [ "$CURRENT_TAG" != "$IMAGE_TAG" ]; then
  echo "$CURRENT_TAG" > "$STATE_DIR/previous_tag"
fi
echo "$IMAGE_TAG" > "$STATE_DIR/current_tag"

# 6. Wait for the container to become healthy (local probe, not the ALB).
echo "Waiting for http://localhost:${APP_PORT}/health ..."
for i in $(seq 1 30); do
  if curl -fsS "http://localhost:${APP_PORT}/health" > /dev/null 2>&1; then
    echo "SUCCESS: container is healthy (attempt ${i})."
    docker ps --filter "name=${CONTAINER_NAME}"
    exit 0
  fi
  sleep 2
done

echo "FAILURE: container did not become healthy within 60s. Last logs:" >&2
docker logs --tail 50 "$CONTAINER_NAME" >&2 || true
exit 1

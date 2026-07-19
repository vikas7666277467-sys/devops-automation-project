#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="${WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
ECR_REPOSITORY_NAME="${ECR_REPOSITORY_NAME:-demoproject_ecr_repo1}"
IMAGE_TAG="${BUILD_NUMBER:-$(git -C "$PROJECT_ROOT" rev-parse --short HEAD)}"

for command in aws docker git curl; do
  command -v "$command" >/dev/null || { echo "Required command is missing: $command" >&2; exit 1; }
done

# aws obtains short-lived credentials automatically from the EC2 instance profile.
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPOSITORY_URL="${ECR_REGISTRY}/${ECR_REPOSITORY_NAME}"
LOCAL_IMAGE="demoproject-nginx:${IMAGE_TAG}"

echo "Authenticating Docker to ${ECR_REGISTRY} with the EC2 IAM role"
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

echo "Building ${LOCAL_IMAGE}"
docker build --pull --tag "$LOCAL_IMAGE" "$PROJECT_ROOT/docker"

echo "Tagging immutable build and rolling latest tags"
docker tag "$LOCAL_IMAGE" "${ECR_REPOSITORY_URL}:${IMAGE_TAG}"
docker tag "$LOCAL_IMAGE" "${ECR_REPOSITORY_URL}:latest"

echo "Pushing images to Amazon ECR"
docker push "${ECR_REPOSITORY_URL}:${IMAGE_TAG}"
docker push "${ECR_REPOSITORY_URL}:latest"

echo "Deploying the immutable build on the Jenkins host"
docker rm --force demoproject-nginx 2>/dev/null || true
docker run --detach \
  --name demoproject-nginx \
  --restart unless-stopped \
  --publish 80:80 \
  "${ECR_REPOSITORY_URL}:${IMAGE_TAG}"

for attempt in {1..12}; do
  if curl --fail --silent http://127.0.0.1/ | grep --quiet 'Welcome to DEMO Project'; then
    echo "Deployment verified: ${ECR_REPOSITORY_URL}:${IMAGE_TAG}"
    exit 0
  fi
  sleep 5
done

echo "Application verification failed" >&2
docker logs demoproject-nginx >&2
exit 1

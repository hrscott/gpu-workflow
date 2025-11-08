#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

# Reuse the same docker detection logic as other scripts
pick_docker_cmd() {
  if docker info > /dev/null 2>&1; then
    echo "docker"
  elif sudo docker info > /dev/null 2>&1; then
    echo "sudo docker"
  else
    echo ""
  fi
}

DOCKER_CMD="$(pick_docker_cmd)"
if [ -z "$DOCKER_CMD" ]; then
  echo "ERROR: Cannot talk to Docker daemon (even with sudo)."
  exit 1
fi

CONTAINER_NAME="$("$DOCKER_CMD" ps --filter 'name=gpu-workflow-app-1' --format '{{.Names}}')"

if [ -z "$CONTAINER_NAME" ]; then
  echo "ERROR: No running app container found."
  echo "       Start it with: ./run_pipeline.sh up"
  exit 1
fi

echo "==> Attaching shell to container: $CONTAINER_NAME"
$DOCKER_CMD exec -it "$CONTAINER_NAME" bash

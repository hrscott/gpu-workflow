#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$ROOT_DIR/docker"

pick_docker_cmd() {
  if docker info >/dev/null 2>&1; then echo "docker"; return; fi
  if command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then echo "sudo docker"; return; fi
  echo "ERROR: Cannot talk to Docker daemon"; exit 1
}

DOCKER_CMD="$(pick_docker_cmd)"
ACTION="${1:-up}"

cd "$DOCKER_DIR"

case "$ACTION" in
  up)
    echo "==> Starting GPU stack..."
    $DOCKER_CMD compose up --quiet-pull
    ;;
  down)
    echo "==> Stopping GPU stack..."
    $DOCKER_CMD compose down
    ;;
  restart)
    echo "==> Restarting GPU stack..."
    $DOCKER_CMD compose down
    $DOCKER_CMD compose up --quiet-pull
    ;;
  logs)
    $DOCKER_CMD compose logs -f
    ;;
  *)
    echo "Usage: $0 [up|down|restart|logs]"
    exit 1
    ;;
esac

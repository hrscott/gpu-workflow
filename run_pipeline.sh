#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$ROOT_DIR/docker"

pick_docker_cmd() {
  if docker info >/dev/null 2>&1; then
    echo "docker"
    return
  fi

  if command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    echo "sudo docker"
    return
  fi

  echo ""
}

DOCKER_CMD="$(pick_docker_cmd)"

if [ -z "$DOCKER_CMD" ]; then
  echo "ERROR: Cannot talk to Docker daemon (even with sudo)." >&2
  echo "       Run ./gpu_preflight.sh or ./bootstrap.sh to diagnose." >&2
  exit 1
fi

if [ "$DOCKER_CMD" = "sudo docker" ]; then
  echo "NOTE: using 'sudo docker' for this session."
  echo "      To use plain 'docker' without sudo, ensure you're in the 'docker' group and either"
  echo "      reconnect your session or run 'newgrp docker' in your shell."
fi

ACTION="${1:-up}"   # up | down | restart | logs

cd "$DOCKER_DIR"

case "$ACTION" in
  up)
    echo "==> Starting GPU stack (docker compose up)..."
    $DOCKER_CMD compose up --quiet-pull
    ;;
  down)
    echo "==> Stopping GPU stack (docker compose down)..."
    $DOCKER_CMD compose down
    ;;
  restart)
    echo "==> Restarting GPU stack..."
    $DOCKER_CMD compose down
    $DOCKER_CMD compose up --quiet-pull
    ;;
  logs)
    echo "==> Streaming logs from all services..."
    $DOCKER_CMD compose logs -f
    ;;
  *)
    echo "Usage: $0 [up|down|restart|logs]"
    exit 1
    ;;
esac
EOF

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER_DIR="$ROOT_DIR/docker"
timestamp="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$ROOT_DIR/env-capture/$timestamp"

mkdir -p "$OUT_DIR"

echo "==> Capturing environment info into $OUT_DIR"

if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi -q > "$OUT_DIR/nvidia-smi.txt"
fi

if docker info >/dev/null 2>&1; then
  docker info > "$OUT_DIR/docker-info.txt"
elif sudo docker info >/dev/null 2>&1; then
  sudo docker info > "$OUT_DIR/docker-info.txt"
fi

if [ -d "$DOCKER_DIR" ]; then
  ( cd "$DOCKER_DIR" && docker compose config > "$OUT_DIR/compose.resolved.yaml" ) || true
fi

cp "$DOCKER_DIR/.env" "$OUT_DIR/.env.snapshot" 2>/dev/null || true

echo "✅ Environment captured."

#!/usr/bin/env bash
set -euo pipefail

pick_docker_cmd() {
  if docker info >/dev/null 2>&1; then
    echo "docker"
    return
  fi
  if command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    echo "sudo docker"
    echo "NOTE: using 'sudo docker'. Log out/in for group changes to apply."
    return
  fi
  echo "ERROR: Cannot access Docker daemon." >&2
  exit 1
}

DOCKER_CMD="$(pick_docker_cmd)"

echo "===== SYSTEM ====="; uname -a || true; echo
echo "===== OS RELEASE ====="; cat /etc/*release 2>/dev/null | sed 's/^/  /'; echo

echo "===== GPU & DRIVER ====="
if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "ERROR: nvidia-smi missing"; exit 1
fi
nvidia-smi || { echo "ERROR: nvidia-smi failed"; exit 1; }

echo "===== CUDA TOOLKIT (optional) ====="
if command -v nvcc >/dev/null 2>&1; then nvcc --version; else echo "nvcc not found (OK)"; fi

echo "===== DOCKER ACCESS ====="
$DOCKER_CMD info | sed -n '/Runtimes/,+4p' || true

echo "===== GPU IN CONTAINER ====="
$DOCKER_CMD run --rm --gpus all nvidia/cuda:12.8.0-runtime-ubuntu22.04 nvidia-smi || {
  echo "ERROR: container cannot access GPUs"; exit 1; }

echo "✅ Preflight PASSED"

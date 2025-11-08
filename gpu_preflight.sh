#!/usr/bin/env bash
set -euo pipefail

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

if [ -z "\$DOCKER_CMD" ]; then
  echo "ERROR: Cannot talk to Docker daemon (even with sudo)." >&2
  echo "       Check 'sudo systemctl status docker' or re-run ./bootstrap.sh." >&2
  exit 1
fi

if [ "\$DOCKER_CMD" = "sudo docker" ]; then
  echo "NOTE: using 'sudo docker'."
  echo "      To use plain 'docker' without sudo:"
  echo "        • Make sure your user is in the 'docker' group,"
  echo "        • Then either reconnect your SSH session, or run 'newgrp docker' in this shell."
fi

echo "===== SYSTEM ====="
uname -a || true
echo

echo "===== OS RELEASE ====="
cat /etc/*release 2>/dev/null | sed 's/^/  /' || true
echo

echo "===== GPU & DRIVER ====="
if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "ERROR: nvidia-smi missing. NVIDIA driver not installed or not in PATH."
  exit 1
fi
nvidia-smi || {
  echo "ERROR: nvidia-smi failed. Check driver installation."
  exit 1
}
echo

echo "===== CUDA TOOLKIT (optional) ====="
if command -v nvcc >/dev/null 2>&1; then
  nvcc --version
else
  echo "nvcc not found (OK; not required for containers)."
fi
echo

echo "===== DOCKER (access & runtimes) ====="
if ! \$DOCKER_CMD info >/dev/null 2>&1; then
  echo "ERROR: '\$DOCKER_CMD info' failed. Docker daemon or permissions issue."
  exit 1
fi

\$DOCKER_CMD info | sed -n '/Runtimes/,+6p' || true
echo

echo "===== IN-CONTAINER GPU VISIBILITY ====="
\$DOCKER_CMD run --rm --gpus all nvidia/cuda:12.8.0-runtime-ubuntu22.04 nvidia-smi || {
  echo "ERROR: container cannot access GPUs. Check NVIDIA runtime configuration."
  exit 1
}

echo
echo " Preflight PASSED: host + Docker + NVIDIA + container GPU all look good."

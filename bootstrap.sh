#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "===== GPU WORKFLOW BOOTSTRAP (Lambda-friendly) ====="
echo "Root directory: $ROOT_DIR"
echo

echo "==> Updating apt package index..."
sudo apt-get update -y

echo
echo "==> Checking for Docker..."
if command -v docker >/dev/null 2>&1; then
  echo "Docker is already installed:"
  docker --version || true
else
  echo "Docker not found; installing distro docker.io..."
  sudo apt-get install -y docker.io
fi

echo
echo "==> Checking for NVIDIA Container Toolkit..."
if dpkg -s nvidia-container-toolkit >/dev/null 2>&1; then
  echo "nvidia-container-toolkit already installed."
else
  echo "nvidia-container-toolkit not installed; installing..."
  sudo apt-get install -y nvidia-container-toolkit
fi

echo
echo "==> Skipping nvidia-container-runtime (not required, avoids containerd conflicts)."

echo
echo "==> Enabling and starting docker service..."
sudo systemctl enable --now docker

echo
echo "==> Ensuring 'docker' group exists and adding current user..."
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker "\$USER" || true

echo
echo "==> Configuring NVIDIA runtime for Docker (if nvidia-ctk is available)..."
if command -v nvidia-ctk >/dev/null 2>&1; then
  sudo nvidia-ctk runtime configure --runtime=docker || {
    echo "WARNING: 'nvidia-ctk runtime configure' failed. Check /etc/docker/daemon.json manually if needed."
  }
else
  echo "WARNING: nvidia-ctk not found. NVIDIA runtime may not be wired into Docker yet."
fi

echo
echo "==> Restarting docker..."
sudo systemctl restart docker

echo
echo "==> Ensuring docker/.env exists..."
if [ ! -f "\$ROOT_DIR/docker/.env" ]; then
  if [ -f "\$ROOT_DIR/docker/.env.example" ]; then
    cp "\$ROOT_DIR/docker/.env.example" "\$ROOT_DIR/docker/.env"
    echo "Created docker/.env from docker/.env.example"
  else
    echo "WARNING: docker/.env.example not found; create docker/.env manually."
  fi
else
  echo "docker/.env already exists; leaving it unchanged."
fi

echo
echo "==> Running GPU preflight checks..."
"\$ROOT_DIR/gpu_preflight.sh" || {
  echo
  echo " Preflight failed. Fix the reported issues and re-run ./bootstrap.sh."
  exit 1
}

echo
echo " bootstrap.sh completed successfully."
echo
echo "NOTE:"
echo "  • Your user was added to the 'docker' group."
echo "  • On a normal SSH session, disconnect and reconnect so group membership applies."
echo "  • On a persistent web shell (like Lambda's browser terminal), run this in a new shell:"
echo "      newgrp docker"
echo "    to refresh your groups for the current session."
echo
echo "When you're ready, start the stack with:"
echo "  ./run_pipeline.sh"

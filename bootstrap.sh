#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "===== GPU WORKFLOW BOOTSTRAP ====="
echo "Root directory: $ROOT_DIR"
echo

echo "==> Updating apt and installing Docker + NVIDIA container toolkit..."
sudo apt-get update -y
sudo apt-get install -y docker.io nvidia-container-toolkit nvidia-container-runtime

echo
echo "==> Enabling and starting docker service..."
sudo systemctl enable --now docker

echo
echo "==> Ensuring 'docker' group exists and adding current user..."
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker "$USER" || true

echo
echo "==> Configuring NVIDIA runtime for Docker..."
if command -v nvidia-ctk >/dev/null 2>&1; then
  sudo nvidia-ctk runtime configure --runtime=docker || {
    echo "WARNING: 'nvidia-ctk runtime configure' failed."
  }
else
  echo "WARNING: nvidia-ctk not found."
fi

echo
echo "==> Restarting docker..."
sudo systemctl restart docker

echo
echo "==> Ensuring docker/.env exists..."
if [ ! -f "$ROOT_DIR/docker/.env" ]; then
  if [ -f "$ROOT_DIR/docker/.env.example" ]; then
    cp "$ROOT_DIR/docker/.env.example" "$ROOT_DIR/docker/.env"
    echo "Created docker/.env from docker/.env.example"
  else
    echo "WARNING: docker/.env.example not found."
  fi
else
  echo "docker/.env already exists."
fi

echo
echo "==> Running GPU preflight checks..."
"$ROOT_DIR/gpu_preflight.sh" || {
  echo "❌ Preflight failed. Fix issues and re-run ./bootstrap.sh."
  exit 1
}

echo
echo "✅ bootstrap.sh completed successfully."
echo "  • If docker still needs sudo, log out/in or reconnect your SSH session."
echo "Next step: ./run_pipeline.sh"

FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# Make apt non-interactive and set sane defaults
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# System packages and build tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 \
        python3-venv \
        python3-pip \
        git \
        wget \
        ca-certificates \
        build-essential \
        libffi-dev \
        libssl-dev \
        libopenblas-dev \
        pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Isolated Python environment
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# Modern packaging tools
RUN pip install --upgrade pip setuptools wheel

# Install JAX with CUDA support and all ColabDesign runtime deps
# (everything from ColabDesign's install_requires EXCEPT jax, which we replace with jax[cuda])
RUN pip install --no-cache-dir \
    "jax[cuda]" \
    py3Dmol absl-py biopython \
    chex dm-haiku dm-tree \
    immutabledict ml-collections \
    numpy pandas scipy optax \
    joblib matplotlib \
    -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html

# Install ColabDesign without pulling its own dependencies
RUN pip install --no-cache-dir \
    "git+https://github.com/sokrypton/ColabDesign.git@v1.1.3" \
    --no-deps

# Add a small compatibility shim for JAX 0.6+ and ColabDesign (jax.tree_map)
RUN python - << 'EOF'
import os, sys
site_dir = next(p for p in sys.path if p.endswith('site-packages'))
sc_path = os.path.join(site_dir, 'sitecustomize.py')
with open(sc_path, 'w') as f:
    f.write(
        "import jax, jax.tree_util\n"
        "if not hasattr(jax, 'tree_map'):\n"
        "    jax.tree_map = jax.tree_util.tree_map\n"
    )
print("Wrote:", sc_path)
EOF

# Default working directory inside the container
WORKDIR /workspace

# Fallback command (docker compose usually overrides this with APP_COMMAND)
CMD ["bash"]

# GPU Workflow for ColabDesign

A reproducible Docker-based GPU environment for running **[ColabDesign](https://github.com/sokrypton/ColabDesign)** and related protein design tools (ProteinMPNN, RFdiffusion, ColabFold, etc.) on cloud GPU instances such as [Lambda Labs](https://lambdalabs.com/).

This repository automates:
- GPU + Docker + NVIDIA Container Toolkit setup
- Building and running a ColabDesign GPU image
- Managing mounted code/data/output directories for persistent workflows

Once built, a new user can go from a fresh GPU instance to a working ColabDesign shell in minutes.

---

## Requirements

- **Host OS:** Ubuntu 22.04 (Lambda GPU instances are ideal)
- **Hardware:** NVIDIA GPU with CUDA capability
- **Internet Access:** Required for package and model downloads
- **Privileges:** `sudo` access (only during initial bootstrap)

---

##  Quickstart (Fresh Lambda GPU Instance)

### 1. Clone this repository

```bash
git clone https://github.com/hrscott/gpu-workflow.git
cd gpu-workflow


2. One-time host setup
Installs Docker, NVIDIA Container Toolkit, and verifies GPU support.

bash
Copy code
./bootstrap.sh
If the script adds you to the docker group, log out and back in (or run newgrp docker) to refresh permissions.

3. Verify GPU & Docker access
Run the included diagnostic:

bash
Copy code
./gpu_preflight.sh
This script checks:

System info and NVIDIA driver

CUDA visibility (nvidia-smi)

Docker runtime configuration

GPU access inside a test container

You should see “GPU inside container is visible!”

4. Prepare environment configuration
Create your local .env and working directories:

bash
Copy code
cd docker
cp .env.example .env
mkdir -p code data outputs
cd ..
By default:

The container uses the image colabdesign-gpu:latest

Code/data/output directories are mounted from docker/

5. Build the ColabDesign GPU image
This image contains:

CUDA 12.8 runtime

GPU-enabled JAX

All ColabDesign dependencies

ColabDesign v1.1.3

Run the helper script:

bash
Copy code
./scripts/build_colabdesign_image.sh
6. Start the workflow stack
bash
Copy code
./run_pipeline.sh up
This starts the ColabDesign container (gpu-workflow-app-1) and any GPU utilities.

Keep this terminal running — it displays container logs.

7. Open a shell inside the container
In a second terminal:

bash
Copy code
./scripts/colabdesign_shell.sh
You’ll now be inside /workspace inside the container.

8. Verify everything works
Inside the container shell:

bash
Copy code
python -c "import jax; print(jax.devices())"
python -c "import colabdesign; print(colabdesign.__file__)"
Expected output:

bash
Copy code
[CudaDevice(id=0)]
/opt/venv/lib/python3.10/site-packages/colabdesign/__init__.py
You now have a fully GPU-accelerated ColabDesign environment.

Directory Mappings
The container mounts host directories defined in .env:

Host Path	Container Path	Purpose
docker/code	/workspace/code	Custom scripts / notebooks
docker/data	/workspace/data	Model weights / reference data
docker/outputs	/workspace/outputs	Output files and results

Examples:

bash
Copy code
# On host
ls docker/code
# Inside container
ls /workspace/code

Building Blocks
Key scripts
Script	Purpose
bootstrap.sh	Installs Docker, NVIDIA toolkit, and configures GPU support
gpu_preflight.sh	Verifies GPU + Docker integration
run_pipeline.sh	Starts/stops Docker Compose stack
scripts/build_colabdesign_image.sh	Builds the colabdesign-gpu:latest image
scripts/colabdesign_shell.sh	Opens a shell in the running ColabDesign container
scripts/capture_env.sh	Snapshots system and Docker environment for debugging

ColabDesign Dockerfile Overview
The image is defined in:

bash
Copy code
docker/colabdesign.Dockerfile
It installs:

CUDA 12.8 runtime

Python + venv

GPU-enabled jax[cuda]

ColabDesign v1.1.3

All dependencies from ColabDesign’s setup.py

You can rebuild it anytime with:

bash
Copy code
./scripts/build_colabdesign_image.sh
Example: Simple ColabDesign Check
Once inside the container:

bash
Copy code
cd /workspace
python - << 'EOF'
from colabdesign import utils
print("ColabDesign is ready.")
EOF
Optional: add your own scripts under /workspace/code to run ProteinMPNN or RFdiffusion pipelines.

Troubleshooting
“permission denied while trying to connect to the Docker daemon socket”
You’re not in the docker group yet.
Run:

bash
Copy code
sudo usermod -aG docker $USER
newgrp docker
Then retry your command.

GPU not visible in JAX ([CpuDevice(id=0)])
The image may not include GPU-enabled JAX.
Rebuild using the provided Dockerfile:

bash
Copy code
./scripts/build_colabdesign_image.sh
./run_pipeline.sh down && ./run_pipeline.sh up
ModuleNotFoundError for Haiku, Chex, etc.
You may have used an outdated image.
Rebuild the latest ColabDesign GPU image as above.

Maintenance Notes
To stop the stack:

bash
Copy code
./run_pipeline.sh down
To rebuild and restart:

bash
Copy code
./scripts/build_colabdesign_image.sh
./run_pipeline.sh restart
To update ColabDesign to a new version, edit the Git tag in
docker/colabdesign.Dockerfile:

dockerfile
Copy code
RUN pip install "git+https://github.com/sokrypton/ColabDesign.git@<new-tag>" --no-deps

Credits
ColabDesign by Sergey Ovchinnikov et al.

JAX by Google Research.

Lambda Labs for easy GPU infrastructure.


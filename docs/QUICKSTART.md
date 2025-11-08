## Note on Docker permissions (Lambda web shell)

If you are using a persistent web shell (e.g., Lambda’s browser terminal) instead of SSH,
your session may not pick up the `docker` group automatically after running `./bootstrap.sh`.

If `./gpu_preflight.sh` prints `NOTE: using 'sudo docker'`, you can run:

```bash
newgrp docker
./gpu_preflight.sh

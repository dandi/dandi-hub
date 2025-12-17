# DANDI Docker Images

Docker images for DandiHub (Nebari-based JupyterHub deployment).

These images extend upstream [Nebari](https://nebari.dev) images with DANDI-specific tools.

## Images

| Image | Base | Description |
|-------|------|-------------|
| `dandiarchive/dandihub:latest-nebari` | nebari-jupyterlab | CPU |
| `dandiarchive/dandihub:latest-nebari-gpu` | nebari-jupyterlab-gpu | GPU/CUDA |
| `dandiarchive/dandihub:latest-matlab` | matlab-integration-for-jupyter | MATLAB |

## dandi/

Extends Nebari jupyterlab with:
- AWS CLI (S3 access for DANDI data)
- rclone + datalad (dataset management)
- git-annex-remote-rclone

## matlab/

MATLAB integration for Nebari with:
- Cleared ENTRYPOINT for Nebari compatibility
- libnss-wrapper for user identity handling
- MATLAB licensing via matlab-proxy

**Note:** MATLAB requires users to provide their own license.

## Local Build

```bash
# dandi CPU
docker build -t dandihub:latest-nebari -f images/dandi/Dockerfile images/dandi

# dandi GPU
docker build \
  --build-arg BASE_IMAGE=quay.io/nebari/nebari-jupyterlab-gpu:2024.11.1 \
  -t dandihub:latest-nebari-gpu \
  -f images/dandi/Dockerfile images/dandi

# matlab
docker build -t dandihub:latest-matlab -f images/matlab/Dockerfile images/matlab
```

## CI

The `docker-build.yaml` workflow:
- Builds on PR (no push) - validates changes
- Pushes to Docker Hub on merge to main

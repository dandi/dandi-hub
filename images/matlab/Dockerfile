ARG MATLAB_RELEASE=r2024b
FROM ghcr.io/mathworks-ref-arch/matlab-integration-for-jupyter/jupyter-matlab-notebook:${MATLAB_RELEASE}

USER root

# Install libnss_wrapper for Nebari user identity handling
RUN apt-get update && apt-get install -y --no-install-recommends libnss-wrapper \
    && rm -rf /var/lib/apt/lists/*

USER $NB_UID

# Clear the ENTRYPOINT so Nebari can control startup
ENTRYPOINT []
CMD ["/bin/bash"]

# Ensure MATLAB licensing env is set (might be needed without start.sh)
ENV MW_CONTEXT_TAGS=MATLAB_PROXY:JUPYTER:V1

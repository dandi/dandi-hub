ARG BASE_IMAGE=quay.io/nebari/nebari-jupyterlab:2024.11.1
FROM ${BASE_IMAGE}

# AWS CLI - for S3 access (DANDI data lives on S3)
RUN curl --silent --show-error "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf ./aws awscliv2.zip

# dandi conda deps (rclone for cloud storage, datalad for dataset management)
COPY environment.yaml /opt/dandi/environment.yaml
RUN /opt/scripts/install-conda-environment.sh /opt/dandi/environment.yaml 'false'

# git-annex-remote-rclone - bridge between git-annex and rclone
# TODO: pin to a specific commit/tag for reproducibility
RUN wget --quiet https://github.com/git-annex-remote-rclone/git-annex-remote-rclone/raw/refs/heads/master/git-annex-remote-rclone \
    && chmod +x git-annex-remote-rclone \
    && mv git-annex-remote-rclone /opt/conda/bin

# fix permissions for multi-user environment
COPY postBuild /opt/dandi/postBuild
RUN /opt/dandi/postBuild

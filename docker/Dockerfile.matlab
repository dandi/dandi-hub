FROM ghcr.io/mathworks-ref-arch/matlab-integration-for-jupyter/jupyter-byoi-matlab-notebook:r2022b

USER root
ARG VERSION="1.1.5"

RUN wget -q https://github.com/apptainer/apptainer/releases/download/v${VERSION}/apptainer_${VERSION}_amd64.deb \
 && wget https://github.com/apptainer/apptainer/releases/download/v${VERSION}/apptainer-suid_${VERSION}_amd64.deb \
 && apt-get update && apt-get install --yes ./apptainer* \
 && rm apptainer*

RUN apt-get update && apt-get install -y ca-certificates libseccomp2 \
   uidmap squashfs-tools squashfuse fuse2fs fuse-overlayfs fakeroot \
   s3fs netbase less parallel tmux screen vim emacs htop curl \
   git \
   && rm -rf /tmp/*

RUN curl --silent --show-error "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
  -o "awscliv2.zip" && unzip awscliv2.zip \
  && ./aws/install && rm -rf ./aws awscliv2.zip

# Install jupyter server proxy and desktop
RUN apt-get -y update \
   && apt-get install -y  \
       dbus-x11 \
       libgl1-mesa-glx \
       firefox \
       xfce4 \
       xfce4-panel \
       xfce4-session \
       xfce4-settings \
       xorg \
       xubuntu-icon-theme \
    && rm -rf /tmp/*

# Remove light-locker to prevent screen lock
ARG TURBOVNC_VERSION=3.0.2
RUN wget -q "https://sourceforge.net/projects/turbovnc/files/${TURBOVNC_VERSION}/turbovnc_${TURBOVNC_VERSION}_amd64.deb/download" -O turbovnc_${TURBOVNC_VERSION}_amd64.deb && \
   apt-get install -y -q ./turbovnc_${TURBOVNC_VERSION}_amd64.deb && \
   apt-get remove -y -q light-locker && \
   rm ./turbovnc_${TURBOVNC_VERSION}_amd64.deb && \
   ln -s /opt/TurboVNC/bin/* /usr/local/bin/ \
    && rm -rf /tmp/*

# apt-get may result in root-owned directories/files under $HOME
RUN mkdir /opt/extras && chown -R $NB_UID:$NB_GID $HOME /opt/extras

USER $NB_USER

RUN pip install --no-cache-dir jupyter-remote-desktop-proxy

RUN mamba install --yes 'datalad>=0.16' rclone 'h5py>3.3=mpi*' ipykernel zarr blosc gcc eccodes websockify \
  && wget --quiet https://raw.githubusercontent.com/DanielDent/git-annex-remote-rclone/v0.7/git-annex-remote-rclone \
  && chmod +x git-annex-remote-rclone && mv git-annex-remote-rclone /opt/conda/bin \
  && conda clean --all -f -y && rm -rf /tmp/*

RUN pip install --no-cache-dir plotly jupyter_bokeh jupytext nbgitpuller datalad_container \
    datalad-osf dandi nibabel nilearn pybids spikeinterface neo \
    'pydra>=0.17' 'pynwb>=2.0.0' 'nwbwidgets>=0.9.0' hdf5plugin s3fs h5netcdf "xarray[io]"  \
    aicsimageio kerchunk 'neuroglancer>=2.28' cloud-volume ipywidgets ome-zarr \
    webio_jupyter_extension https://github.com/balbasty/dandi-io/archive/refs/heads/main.zip \
    tensorstore anndata

# RUN pip install --no-cache-dir --upgrade 'itkwidgets[lab]>=1.0a8' ipywidgets

FROM golang:1.19.3 as builder

ARG VERSION="1.1.3"

WORKDIR $GOPATH/src/github.com/apptainer
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    build-essential \
    libseccomp-dev \
    pkg-config \
    uidmap \
    squashfs-tools \
    squashfuse \
    fuse2fs \
    fuse-overlayfs \
    fakeroot \
    cryptsetup \
    curl wget git
RUN wget -q https://github.com/apptainer/apptainer/releases/download/v${VERSION}/apptainer-${VERSION}.tar.gz && \
    tar -xzf apptainer-${VERSION}.tar.gz && \
    cd apptainer-${VERSION} && \
    ./mconfig --prefix=/opt/apptainer --without-suid && \
    make -C ./builddir && \
    make -C ./builddir install

FROM ghcr.io/mathworks-ref-arch/matlab-integration-for-jupyter/jupyter-byoi-matlab-notebook:r2022b

USER root
COPY --from=builder /opt/apptainer /opt/apptainer
ENV PATH="/opt/apptainer/bin:$PATH"
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
   && apt-get install -y dbus-x11 \
       firefox \
       xfce4 \
       xfce4-panel \
       xfce4-session \
       xfce4-settings \
       xorg \
       xubuntu-icon-theme \
    && rm -rf /tmp/*

# Remove light-locker to prevent screen lock
ARG TURBOVNC_VERSION=3.0.1
RUN wget -q "https://sourceforge.net/projects/turbovnc/files/${TURBOVNC_VERSION}/turbovnc_${TURBOVNC_VERSION}_amd64.deb/download" -O turbovnc_${TURBOVNC_VERSION}_amd64.deb && \
   apt-get install -y -q ./turbovnc_${TURBOVNC_VERSION}_amd64.deb && \
   apt-get remove -y -q light-locker && \
   rm ./turbovnc_${TURBOVNC_VERSION}_amd64.deb && \
   ln -s /opt/TurboVNC/bin/* /usr/local/bin/ \
    && rm -rf /tmp/*

# apt-get may result in root-owned directories/files under $HOME
RUN mkdir /opt/extras && chown -R $NB_UID:$NB_GID $HOME /opt/extras

USER $NB_USER

RUN cd /opt/extras && \
    git clone --depth 1 https://github.com/jupyterhub/jupyter-remote-desktop-proxy.git && \
    cd jupyter-remote-desktop-proxy && \
    mamba env update -n base --file environment.yml && \
    cd /opt && rm -rf /opt/extras/* && \
    conda clean --all -f -y && rm -rf /tmp/*

RUN mamba install --yes 'datalad>=0.16' rclone 'h5py>3.3=mpi*' ipykernel zarr blosc gcc eccodes \
  && wget --quiet https://raw.githubusercontent.com/DanielDent/git-annex-remote-rclone/v0.7/git-annex-remote-rclone \
  && chmod +x git-annex-remote-rclone && mv git-annex-remote-rclone /opt/conda/bin \
  && conda clean --all -f -y && rm -rf /tmp/*

RUN pip install --no-cache-dir plotly jupyter_bokeh jupytext nbgitpuller datalad_container \
    datalad-osf dandi nibabel nilearn pybids spikeinterface neo \
    'pydra>=0.17' 'pynwb>=2.0.0' 'nwbwidgets>=0.9.0' hdf5plugin s3fs h5netcdf "xarray[io]"  \
    aicsimageio kerchunk 'neuroglancer>=2.28' cloud-volume 'ipywidgets<8' ome-zarr \
    webio_jupyter_extension https://github.com/balbasty/dandi-io/archive/refs/heads/main.zip

# RUN pip install --no-cache-dir --upgrade 'itkwidgets[lab]>=1.0a8' 'ipywidgets<8'

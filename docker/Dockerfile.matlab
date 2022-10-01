FROM golang:1.17.7 as builder

ARG VERSION="1.1.0"

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

FROM ghcr.io/mathworks-ref-arch/matlab-integration-for-jupyter/jupyter-byoi-matlab-notebook:r2022a

USER root
COPY --from=builder /opt/apptainer /opt/apptainer
ENV PATH="/opt/apptainer/bin:$PATH"
RUN apt-get update && apt-get install -y ca-certificates libseccomp2 \
   uidmap squashfs-tools squashfuse fuse2fs fuse-overlayfs fakeroot \
   s3fs netbase less parallel tmux screen vim htop curl \
   && rm -rf /tmp/*

RUN curl --silent --show-error "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
  -o "awscliv2.zip" && unzip awscliv2.zip \
  && ./aws/install && rm -rf ./aws awscliv2.zip

USER $NB_USER

RUN mamba install --yes 'datalad>=0.16' rclone 'h5py>3.3=mpi*' ipykernel zarr blosc jupyter_bokeh \
  && wget --quiet https://raw.githubusercontent.com/DanielDent/git-annex-remote-rclone/v0.6/git-annex-remote-rclone \
  && chmod +x git-annex-remote-rclone && mv git-annex-remote-rclone /opt/conda/bin \
  && pip install --no-cache-dir jupytext nbgitpuller datalad_container \
     datalad-osf dandi nibabel nilearn pybids spikeinterface neo \
     'pydra>=0.17' nwbwidgets 'pynwb>=2.0.0' plotly 'itkwidgets[lab]>=1.0a8' hdf5plugin s3fs \
     h5netcdf "xarray[io]" aicsimageio kerchunk \
  && conda clean --all -f -y && rm -rf /tmp/*

RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager \
  jupyter-matplotlib jupyterlab-datawidgets jupyter-threejs --no-build \
  && export NODE_OPTIONS=--max-old-space-size=4096 \
  && jupyter lab build && \
     jupyter lab clean && \
     jlpm cache clean && \
     npm cache clean --force && \
     rm -rf $HOME/.node-gyp && \
     rm -rf $HOME/.local && rm -rf /tmp/*

# Install jupyter server proxy and desktop
USER root

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
ARG TURBOVNC_VERSION=2.2.6
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
    conda env update -n base --file environment.yml && \
    cd /opt && rm -rf /opt/extras/* && \
    conda clean --all -f -y && rm -rf /tmp/*

RUN pip install --no-cache-dir 'neuroglancer>=2.28' tifffile
RUN pip install --no-cache-dir ome-zarr
RUN pip install --no-cache-dir --upgrade boto3 s3fs
RUN mamba install --yes napari && \
    pip install --no-cache-dir napari-ome-zarr && \
    conda clean --all -f -y && rm -rf /tmp/*
RUN pip install --no-cache-dir --upgrade webio_jupyter_extension
RUN pip install --no-cache-dir --upgrade multiscale_spatial_image dask_image \
    https://github.com/balbasty/dandi-io/archive/refs/heads/main.zip

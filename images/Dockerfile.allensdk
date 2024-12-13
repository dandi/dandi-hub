FROM quay.io/jupyter/datascience-notebook:2024-02-06

USER root

RUN apt update \
 && apt install -y software-properties-common \
 && add-apt-repository -y 'ppa:apptainer/ppa' \
 && apt update \
 && apt install -y apptainer-suid \
 && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*

RUN apt-get update && apt-get install -y ca-certificates libseccomp2 \
   s3fs netbase less parallel tmux screen vim emacs htop curl \
   && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*

RUN curl --silent --show-error "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
  -o "awscliv2.zip" && unzip awscliv2.zip \
  && ./aws/install && rm -rf ./aws awscliv2.zip

# Install jupyter server proxy and desktop
RUN curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
   && echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list \
   && apt-get -y -qq update \
   && apt-get -y -qq install \
        dbus-x11 \
        xfce4 \
        xfce4-panel \
        xfce4-session \
        xfce4-settings \
        xorg \
        xubuntu-icon-theme \
        brave-browser \
        tigervnc-standalone-server \
        tigervnc-xorg-extension \
    # chown $HOME to workaround that the xorg installation creates a
    # /home/jovyan/.cache directory owned by root
   && chown -R $NB_UID:$NB_GID $HOME \
   && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*

# apt-get may result in root-owned directories/files under $HOME
RUN mkdir /opt/extras && chown -R $NB_UID:$NB_GID $HOME /opt/extras

USER $NB_USER

RUN pip install --no-cache-dir jupyter-remote-desktop-proxy

# Install Allen SDK
RUN mamba create --yes -n allen -c conda-forge python=3.8 pip ipykernel 'h5py>=3.4=mpi*' \
  && /opt/conda/envs/allen/bin/pip install --no-cache-dir allensdk \
  && conda clean --all -f -y && rm -rf /tmp/*

RUN mamba install --yes 'datalad>=0.18' rclone 'h5py>3.3=mpi*' ipykernel zarr blosc eccodes websockify \
  && wget --quiet https://raw.githubusercontent.com/DanielDent/git-annex-remote-rclone/v0.8/git-annex-remote-rclone \
  && chmod +x git-annex-remote-rclone && mv git-annex-remote-rclone /opt/conda/bin \
  && conda clean --all -f -y && rm -rf /tmp/*

RUN /opt/conda/envs/allen/bin/python -m ipykernel install --user --name allen \
    --display-name="Allen SDK"

RUN pip install --no-cache-dir -U plotly jupyter_bokeh jupytext nbgitpuller datalad_container \
    datalad-osf dandi nibabel nilearn pybids spikeinterface neo itkwidgets \
    'pydra>=0.17' 'pynwb>=2.3.1' 'nwbwidgets>=0.10.2' hdf5plugin s3fs h5netcdf "xarray[io]"  \
    aicsimageio kerchunk 'neuroglancer>=2.28' cloud-volume ipywidgets ome-zarr \
    webio_jupyter_extension https://github.com/balbasty/dandi-io/archive/refs/heads/main.zip \
    tensorstore anndata

RUN pip install --no-cache-dir multiscale_spatial_image jupyterlab-git \
        datalad-fuse

RUN pip install --no-cache-dir brainrender napari

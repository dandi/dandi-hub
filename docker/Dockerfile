FROM golang:1.15.2 as builder

ARG SINGULARITY_COMMITISH="v3.7.1"

WORKDIR $GOPATH/src/github.com/sylabs
RUN apt-get update && apt-get install -y \
    build-essential \
    uuid-dev \
    libgpgme-dev \
    squashfs-tools \
    libseccomp-dev \
    wget \
    pkg-config \
    git \
    cryptsetup-bin
RUN git clone https://github.com/sylabs/singularity.git \
    && cd singularity \
    && git checkout "$SINGULARITY_COMMITISH" \
    && ./mconfig -p /usr/local/singularity \
    && cd builddir \
    && make \
    && make install

FROM jupyter/datascience-notebook:59c973d16bca

USER root
COPY --from=builder /usr/local/singularity /usr/local/singularity
ENV PATH="/usr/local/singularity/bin:$PATH"
RUN apt-get update && apt-get install -y ca-certificates libseccomp2 \
   squashfs-tools fuse s3fs netbase less parallel tmux vim \
   && rm -rf /tmp/*

RUN curl --silent --show-error "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
  -o "awscliv2.zip" && unzip awscliv2.zip \
  && ./aws/install && rm -rf ./aws awscliv2.zip

RUN wget --quiet https://github.com/kahing/goofys/releases/download/v0.24.0/goofys \
  && chmod +x goofys && mv goofys /usr/local/bin

USER $NB_USER

# Install Allen SDK
RUN conda create -n allen python=3.8 pip numpy cython numexpr ipykernel \
  && HDF5_DIR=/opt/conda BLOSC_DIR=/opt/conda LZO_DIR=/opt/conda \
  BZIP2_DIR=/opt/conda /opt/conda/envs/allen/bin/pip install tables==3.5.1 \
  && /opt/conda/envs/allen/bin/pip install --no-cache-dir ipfx \
  && /opt/conda/envs/allen/bin/python -m ipykernel install --user --name allen \
  --display-name="Allen SDK" \
  && conda clean -tipsy && rm -rf /tmp/*

# Install packages into base env
RUN conda install --yes datalad rclone \
  && wget --quiet https://raw.githubusercontent.com/DanielDent/git-annex-remote-rclone/v0.6/git-annex-remote-rclone \
  && chmod +x git-annex-remote-rclone && mv git-annex-remote-rclone /opt/conda/bin \
  && pip install --no-cache-dir itkwidgets==0.32.0 jupytext plotly \
  nbgitpuller nibabel nilearn pybids zarr spikeinterface neo \
  git+https://github.com/dandi/dandi-cli.git \
  git+https://github.com/nipype/pydra.git \
  datalad-container datalad-osf nwbwidgets \
  && conda clean -tipsy && rm -rf /tmp/*

RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager \
  jupyter-matplotlib jupyterlab-datawidgets itkwidgets@0.32.0 jupyterlab-plotly \
  plotlywidget jupyter-threejs --no-build \
  && export NODE_OPTIONS=--max-old-space-size=4096 \
  && jupyter lab build && \
     jupyter lab clean && \
     jlpm cache clean && \
     npm cache clean --force && \
     rm -rf $HOME/.node-gyp && \
     rm -rf $HOME/.local && rm -rf /tmp/*

# Create streaming NWB environment
RUN conda create -n ros3 -c conda-forge python=3.8 hdf5 h5py ipykernel pip \
  numpy matplotlib \
  && /opt/conda/envs/ros3/bin/python -m ipykernel install --user --name ros3 \
  --display-name="Streaming NWB" \
  && /opt/conda/envs/ros3/bin/pip install --no-cache-dir \
  git+https://github.com/hdmf-dev/hdmf.git@enh/h5py3 \
  git+https://github.com/NeurodataWithoutBorders/pynwb.git \
  nwbwidgets \
  && conda install -n ros3 -c conda-forge --force-reinstall h5py=3.2.1 \
  && conda clean -tipsy && rm -rf /tmp/*

RUN gitpuller https://github.com/dandi/example-notebooks master dandi-notebooks

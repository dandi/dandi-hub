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

FROM jupyter/datascience-notebook:016833b15ceb

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
RUN conda create -n allen python=3.8 pip numpy cython numexpr ipykernel
RUN HDF5_DIR=/opt/conda BLOSC_DIR=/opt/conda LZO_DIR=/opt/conda \
  BZIP2_DIR=/opt/conda /opt/conda/envs/allen/bin/pip install tables==3.5.1
RUN /opt/conda/envs/allen/bin/pip install --no-cache-dir ipfx
RUN /opt/conda/envs/allen/bin/python -m ipykernel install --user --name allen \
  --display-name="Allen SDK"
RUN conda clean -tipsy

RUN pip install --no-cache-dir itkwidgets==0.32.0 jupytext plotly pyvista
RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager \
  jupyter-matplotlib jupyterlab-datawidgets itkwidgets@0.32.0 jupyterlab-plotly \
  plotlywidget jupyter-threejs --no-build \
  && export NODE_OPTIONS=--max-old-space-size=4096 \
  && jupyter lab build && rm -rf /tmp/*

RUN pip install --no-cache-dir nbgitpuller nibabel nilearn pybids zarr \
  spikeinterface neo

RUN conda create -n ros3 -c conda-forge hdf5 h5py ipykernel pip numpy \
  matplotlib && conda clean -tipsy && \
  /opt/conda/envs/ros3/bin/python -m ipykernel install --user --name ros3 \
  --display-name="Streaming NWB"

RUN conda install --yes datalad rclone \
  && conda clean -tipsy \
  && wget --quiet https://raw.githubusercontent.com/DanielDent/git-annex-remote-rclone/v0.6/git-annex-remote-rclone \
  && chmod +x git-annex-remote-rclone && mv git-annex-remote-rclone /opt/conda/bin

RUN gitpuller https://github.com/dandi/example-notebooks master dandi-notebooks
RUN pip install --no-cache-dir \
  git+https://github.com/dandi/dandi-cli.git \
  git+https://github.com/nipype/pydra.git \
  datalad datalad-container datalad-osf nwbwidgets
RUN /opt/conda/envs/ros3/bin/pip install --no-cache-dir \
  git+https://github.com/hdmf-dev/hdmf.git@enh/h5py3 \
  git+https://github.com/NeurodataWithoutBorders/pynwb.git \
  nwbwidgets

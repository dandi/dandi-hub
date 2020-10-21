FROM golang:1.15.2 as builder

ARG SINGULARITY_COMMITISH="master"

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

FROM jupyter/datascience-notebook:4a112c0f11eb

USER root
COPY --from=builder /usr/local/singularity /usr/local/singularity
ENV PATH="/usr/local/singularity/bin:$PATH"
RUN apt-get update && apt-get install -y ca-certificates libseccomp2 \
   squashfs-tools fuse s3fs git-annex rclone \
    && rm -rf /tmp/*

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
  -o "awscliv2.zip" && unzip awscliv2.zip \
  && ./aws/install && rm -rf ./aws awscliv2.zip

RUN wget https://github.com/kahing/goofys/releases/download/v0.24.0/goofys \
  && chmod +x goofys && mv goofys /usr/local/bin

USER $NB_USER

RUN pip install --no-cache-dir itkwidgets==0.32.0
RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager jupyter-matplotlib jupyterlab-datawidgets itkwidgets@0.32.0

RUN pip install --no-cache-dir nwbwidgets zarr pydra dandi spikeinterface

RUN conda create -n allen python=3.8 pip numpy cython numexpr ipykernel
RUN HDF5_DIR=/opt/conda BLOSC_DIR=/opt/conda LZO_DIR=/opt/conda BZIP2_DIR=/opt/conda /opt/conda/envs/allen/bin/pip install tables==3.5.1
RUN /opt/conda/envs/allen/bin/pip install --no-cache-dir ipfx
RUN conda clean -tipsy

RUN jupyter lab build
RUN pip install --no-cache-dir nbgitpuller nibabel pybids pydra-ml \
  datalad datalad-container nilearn

RUN gitpuller https://github.com/dandi/example-notebooks master dandi-notebooks

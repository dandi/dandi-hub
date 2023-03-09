FROM --platform=linux/amd64 ghcr.io/mathworks-ref-arch/matlab-integration-for-jupyter/jupyter-byoi-matlab-notebook:r2022b

USER root
ARG VERSION="1.1.5"

ARG EXTRA_DIR=/opt/extras

RUN wget -q https://github.com/apptainer/apptainer/releases/download/v${VERSION}/apptainer_${VERSION}_amd64.deb \
 && wget https://github.com/apptainer/apptainer/releases/download/v${VERSION}/apptainer-suid_${VERSION}_amd64.deb \
 && apt-get update && apt-get install --yes ./apptainer* \
 && rm apptainer*

RUN apt-get update && apt-get install -y ca-certificates libseccomp2 \
   uidmap squashfs-tools squashfuse fuse2fs fuse-overlayfs fakeroot \
   s3fs netbase less parallel tmux screen vim emacs htop curl \
   git build-essential \
   && rm -rf /tmp/*

RUN curl --silent --show-error "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
  -o "awscliv2.zip" && unzip awscliv2.zip \
  && ./aws/install && rm -rf ./aws awscliv2.zip

# Install jupyter server proxy and desktop
RUN curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
   && echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list \
   && apt-get -y update \
   && apt-get install -y  \
       dbus-x11 \
       libgl1-mesa-glx \
       xfce4 \
       xfce4-panel \
       xfce4-session \
       xfce4-settings \
       xorg \
       xubuntu-icon-theme \
       brave-browser \
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
RUN mkdir ${EXTRA_DIR} && chown -R $NB_UID:$NB_GID $HOME ${EXTRA_DIR}

USER $NB_USER

RUN pip install --no-cache-dir jupyter-remote-desktop-proxy

RUN mamba install --yes 'datalad>=0.18' rclone 'h5py>3.3=mpi*' ipykernel zarr blosc gcc eccodes websockify \
  && wget --quiet https://raw.githubusercontent.com/DanielDent/git-annex-remote-rclone/v0.7/git-annex-remote-rclone \
  && chmod +x git-annex-remote-rclone && mv git-annex-remote-rclone /opt/conda/bin \
  && conda clean --all -f -y && rm -rf /tmp/*

RUN pip install --no-cache-dir plotly jupyter_bokeh jupytext nbgitpuller datalad_container \
    datalad-osf dandi nibabel nilearn pybids spikeinterface neo \
    'pydra>=0.17' 'pynwb>=2.0.0' 'nwbwidgets>=0.10.1' hdf5plugin s3fs h5netcdf "xarray[io]"  \
    aicsimageio kerchunk 'neuroglancer>=2.28' cloud-volume ipywidgets ome-zarr \
    webio_jupyter_extension https://github.com/balbasty/dandi-io/archive/refs/heads/main.zip \
    tensorstore anndata

# Install the jupyter-matlab kernel and matlab-proxy
RUN pip install --no-cache-dir jupyter-matlab-proxy

## Adds add-ons and register them in the Matlab instance
# Patch startup.m to automatically register the addons
# The registration process simply iterate over all entries from the ADDONS_DIR folder
# and add them to the "path"
ARG ADDONS_DIR=${EXTRA_DIR}/dandi

RUN echo -e "\n\
addons = dir('${ADDONS_DIR}'); \n\
addons = setdiff({addons([addons.isdir]).name}, {'.', '..'}); \n\
for addon_idx = 1:numel(addons) \n\
    addpath(strcat('${ADDONS_DIR}/', addons{addon_idx})); \n\
end \n\
generateCore();  % Generate the most recent nwb-schema \n\
% ADD HERE EXTRA ACTIONS FOR YOUR ADD-ON IF REQUIRED! \n\
clear" >> /opt/conda/lib/python3.10/site-packages/matlab_proxy/matlab/startup.m

# Variables for addons management that are tied to a specific release
ARG ADDONS_RELEASES="https://github.com/NeurodataWithoutBorders/matnwb/archive/refs/tags/v2.6.0.0.zip"

# Add add-ons for Dandi: create the addons folder and download/unzip the addons
RUN mkdir ${ADDONS_DIR} && \
    cd ${ADDONS_DIR} && \
    for addon in $ADDONS_RELEASES; do \
       wget -O addon.zip $addon \
       && unzip addon.zip \
       && rm addon.zip; \
    done

# Variables for addons management that always takes the last release
ARG ADDONS_LATEST="https://github.com/emeyers/Brain-Observatory-Toolbox"

# Add add-ons for Dandi: detect/download/unzip the last release version
RUN cd ${ADDONS_DIR} && \
    for addon in $ADDONS_LATEST; do \
       wget -O addon.zip $(echo "$addon/releases/latest" | sed 's/\/github.com\//\/api.github.com\/repos\//' | xargs wget -qO- |  grep zipball_url | cut -d '"' -f 4) \
       && unzip addon.zip; \
       echo -e "\n\
add_path(\"${ADDONS_DIR}/$(unzip -Z -1 addon.zip | head -1)quickstarts\"); \n\
add_path(\"${ADDONS_DIR}/$(unzip -Z -1 addon.zip | head -1)demos\"); \n\
add_path(\"${ADDONS_DIR}/$(unzip -Z -1 addon.zip | head -1)tutorials\");\n\
clear" >> /opt/conda/lib/python3.10/site-packages/matlab_proxy/matlab/startup.m \
       && rm addon.zip; \
    done
# The copy of the quickstarts/demos/tutorials folder in the startup.m file are temporary
ARG MATLAB_RELEASE=r2024b
FROM --platform=linux/amd64 ghcr.io/mathworks-ref-arch/matlab-integration-for-jupyter/jupyter-matlab-notebook:${MATLAB_RELEASE}

USER root

# install extra apps, add extra folder and fix ownership in case apt-get messed with it
ARG EXTRA_DIR=/opt/extras
RUN df -h && apt-get update \
    && apt-get install -y \
        htop \
        libnss-wrapper \
        curl \
        git \
        build-essential \
    && rm -rf /tmp/* \
    && mkdir ${EXTRA_DIR} \
    && chown -R $NB_UID:$NB_GID $HOME ${EXTRA_DIR}

RUN df -h && pip install --no-cache-dir datalad 'h5py>3.3' zarr pyopenssl plotly jupyter_bokeh jupytext nbgitpuller datalad_container \
    datalad-osf dandi nibabel nilearn pybids spikeinterface neo \
    'pydra>=0.25' 'pynwb>=2.8.3' 'nwbwidgets>=0.10.2' hdf5plugin s3fs h5netcdf "xarray[io]"  \
    aicsimageio kerchunk 'neuroglancer>=2.28' cloud-volume ipywidgets ome-zarr \
    webio_jupyter_extension https://github.com/balbasty/dandi-io/archive/refs/heads/main.zip \
    tensorstore anndata tensorflow

# Install the required Toolboxes with user root
# Optimization toolbox is a required dependency
ARG MATLAB_RELEASE
ARG TOOLBOXES="Bioinformatics_Toolbox \
               Computer_Vision_Toolbox \
               Curve_Fitting_Toolbox \
               Deep_Learning_Toolbox \
               Econometrics_Toolbox \
               Image_Processing_Toolbox \
               Optimization_Toolbox \
               Statistics_and_Machine_Learning_Toolbox \
               Signal_Processing_Toolbox \
               Parallel_Computing_Toolbox \
               Financial_Toolbox \
               Wavelet_Toolbox \
               Deep_Learning_Toolbox_Converter_for_TensorFlow_models"
RUN df -h && wget -q https://www.mathworks.com/mpm/glnxa64/mpm && \
    chmod +x mpm && \
    ./mpm install \
    --release=${MATLAB_RELEASE} \
    --destination=/opt/matlab \
    --products ${TOOLBOXES} && \
    rm -f mpm /tmp/mathworks_root.log

# Switch to NB_USER for addons and live-scripts installations
USER $NB_USER

## Adds add-ons and register them in the Matlab instance
# Patch startup.m to automatically register the addons
# The registration process simply iterate over all entries from the ADDONS_DIR folder
# and add them to the "path"
ARG ADDONS_DIR=${EXTRA_DIR}/dandi
ARG STARTUP_SCRIPT=/opt/conda/lib/python3.11/site-packages/matlab_proxy/matlab/startup.m

# Generate MATLAB startup script
RUN df -h && echo -e "\n\
% Set the number of workers for 'Processes' to 5\n\
cluster = parcluster('Processes'); \n\
cluster.NumWorkers = 5; \n\
saveProfile(cluster); \n\
 \n\
% Copy the live-example folder \n\
homedirExamples = strcat(getenv('HOME'), '/example-live-scripts') \n\
if not(isfolder(homedirExamples)) \n\
    repo = gitclone('https://github.com/MATLAB-Community-Toolboxes-at-INCF/example-live-scripts', homedirExamples, Depth=1); \n\
end \n\
% Add the example library to the path \n\
addpath(homedirExamples); \n\
% Add the addons to the path \n\
addons = dir('${ADDONS_DIR}'); \n\
addons = setdiff({addons([addons.isdir]).name}, {'.', '..'}); \n\
for addon_idx = 1:numel(addons) \n\
    addpath(genpath(strcat('${ADDONS_DIR}/', addons{addon_idx}))); \n\
end \n\
% generateCore();  % Generate the most recent nwb-schema \n\
% ciapkg.io.loadDependencies('guiEnabled', 0);  % Load dependencies for CIAtah \n\
% ADD HERE EXTRA ACTIONS FOR YOUR ADD-ON IF REQUIRED! \n\
clear" >> ${STARTUP_SCRIPT}

# Variables for addons management that are tied to a specific release or commit
ARG ADDONS_RELEASES="https://github.com/NeurodataWithoutBorders/matnwb/archive/2c3a4e13c9504724c08f3d937c08c730accf7685.zip \
                     https://github.com/schnitzer-lab/EXTRACT-public/archive/refs/heads/master.zip \
                     https://github.com/bahanonu/ciatah/archive/refs/heads/master.zip"

# Add add-ons for Dandi: create the addons folder and download/unzip the addons
RUN df -h && mkdir -p ${ADDONS_DIR} && \
    cd ${ADDONS_DIR} && \
    for addon in $ADDONS_RELEASES; do \
       wget -O addon.zip $addon \
       && unzip addon.zip \
       && rm addon.zip; \
    done

# Variables for addons management that always takes the last release
ARG ADDONS_LATEST="https://github.com/emeyers/Brain-Observatory-Toolbox"

# Add add-ons for Dandi: detect/download/unzip the last release version
RUN df -h && cd ${ADDONS_DIR} && \
    for addon in $ADDONS_LATEST; do \
       wget -O addon.zip $(echo "$addon/releases/latest" | sed 's/\/github.com\//\/api.github.com\/repos\//' | xargs wget -qO- |  grep zipball_url | cut -d '"' -f 4) \
       && unzip addon.zip \
       && rm addon.zip; \
    done

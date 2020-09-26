FROM jupyter/datascience-notebook:612aa5710bf9

RUN pip install --no-cache-dir itkwidgets==0.32.0
RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager jupyter-matplotlib jupyterlab-datawidgets itkwidgets@0.32.0

RUN pip install --no-cache-dir nwbwidgets zarr pydra dandi spikeinterface

RUN conda create -n allen python=3.8 pip numpy cython numexpr
RUN HDF5_DIR=/opt/conda BLOSC_DIR=/opt/conda LZO_DIR=/opt/conda BZIP2_DIR=/opt/conda /opt/conda/envs/allen/bin/pip install tables==3.5.1
RUN /opt/conda/envs/allen/bin/pip install --no-cache-dir ipfx
RUN conda clean -tipsy

RUN jupyter lab build
RUN pip install --no-cache-dir nbgitpuller
RUN gitpuller https://github.com/dandi/example-notebooks master dandi-notebooks

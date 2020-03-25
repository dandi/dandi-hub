FROM jupyter/datascience-notebook:dc9744740e12

RUN pip install --no-cache-dir nwbwidgets==0.2.0
RUN pip install --no-cache-dir itkwidgets==0.25.3
RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager jupyter-matplotlib jupyterlab-datawidgets itkwidgets@0.25.3

# Install allendsk but upgrade pynwb
RUN pip install --no-cache-dir allensdk
RUN pip install --no-cache-dir --upgrade pynwb

RUN pip install --no-cache-dir zarr pydra dandi

RUN pip install --no-cache-dir nbgitpuller
RUN gitpuller https://github.com/dandi/example-notebooks master dandi-notebooks

FROM jupyter/datascience-notebook:7a0c7325e470

RUN pip install reactopya_jup==0.9.1
RUN jupyter labextension install reactopya_jup@0.9.1
RUN jupyter nbextension install --sys-prefix --py reactopya_jup
RUN jupyter nbextension enable reactopya_jup --py --sys-prefix

RUN pip install ephys_viz==0.9.3
RUN pip install nwbwidgets

RUN pip install --no-cache-dir nbgitpuller

USER root
# https://bugs.debian.org/830696 (apt uses gpgv by default in newer releases, rather than gpg)
RUN set -x \
	&& apt-get update \
	&& { \
		which gpg \
		|| apt-get install -y --no-install-recommends gnupg \
	; } \
# Ubuntu includes "gnupg" (not "gnupg2", but still 2.x), but not dirmngr, and gnupg 2.x requires dirmngr
# so, if we're not running gnupg 1.x, explicitly install dirmngr too
	&& { \
		gpg --version | grep -q '^gpg (GnuPG) 1\.' \
		|| apt-get install -y --no-install-recommends dirmngr \
	; } \
	&& rm -rf /var/lib/apt/lists/*

# apt-key is a bit finicky during "docker build" with gnupg 2.x, so install the repo key the same way debian-archive-keyring does (/etc/apt/trusted.gpg.d)
# this makes "apt-key list" output prettier too!
RUN set -x \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys DD95CC430502E37EF840ACEEA5D32F012649A5A9 \
	&& gpg --batch --export DD95CC430502E37EF840ACEEA5D32F012649A5A9 > /etc/apt/trusted.gpg.d/neurodebian.gpg \
	&& rm -rf "$GNUPGHOME" \
	&& apt-key list | grep neurodebian

RUN mkdir /data && chown jovyan /data && chmod 777 /data && mkdir /output && chown jovyan /output && chmod 777 /output && mkdir /repos && chown jovyan /repos && chmod 777 /repos
RUN { \
	echo 'deb http://neuro.debian.net/debian trusty main'; \
	echo 'deb http://neuro.debian.net/debian data main'; \
	echo '#deb-src http://neuro.debian.net/debian-devel trusty main'; \
} > /etc/apt/sources.list.d/neurodebian.sources.list

RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           git-annex-standalone httpfs2 fuse \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER $NB_USER
RUN pip install --no-cache-dir datalad[full] zarr
RUN pip install --no-cache-dir https://github.com/nipype/pydra/archive/c8ecd2965741065a98174576f1b82a8289adcd13.zip
RUN pip install --no-cache-dir https://github.com/dandi/dandi-cli/archive/da557f231e5d211475d8aa3e1655845aebc1b43a.zip
RUN cd /data && datalad install -r ///labs/svoboda ///labs/buzsaki \
    ///labs/churchland ///allen-brain-observatory/
RUN pip install --no-cache-dir allensdk
RUN pip install --no-cache-dir --upgrade pynwb

RUN gitpuller https://github.com/flatironinstitute/ephys-viz master ephys-viz
RUN gitpuller https://github.com/NeurodataWithoutBorders/nwb-jupyter-widgets master nwb-jupyter-widgets
RUN gitpuller https://github.com/dandi/example-notebooks master dandi-notebooks

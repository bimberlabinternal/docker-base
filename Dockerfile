FROM rocker/rstudio:latest
ENV R_BIOC_VERSION=3.20

ARG GH_PAT='NOT_SET'

# NOTE: inkscape and librsvg2-bin installed for CoNGA
# NOTE: locales / locales-all added due to errors with install_deps() and special characters in the DESCRIPTION file for niaid/dsb
RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y \
        libhdf5-dev \
        python3-full \
        python3-pip \
        libpython3-dev \
        inkscape \
        librsvg2-bin \
        locales \
        locales-all \
        wget \
        git \
        libxml2-dev \
        libxslt-dev \
        libgdal-dev \
        libicu-dev \
        libglpk-dev \
        libbz2-dev \
	    cargo \
    # This avoids the 'error: externally-managed-environment' issue
    && rm -Rf /usr/lib/python3.12/EXTERNALLY-MANAGED \
    && Rscript -e "install.packages(c('remotes', 'devtools', 'BiocManager', 'pryr', 'rmdformats', 'knitr', 'logger', 'Matrix'), dependencies=TRUE, ask = FALSE, upgrade = 'always')" \
    && echo "local({options(repos = BiocManager::repositories())})" >> ~/.Rprofile \
    # NOTE: this was added to avoid the build dying if this downloads a binary built on a later R version
    && echo "Sys.setenv(R_REMOTES_NO_ERRORS_FROM_WARNINGS='true');" >> ~/.Rprofile \
    && Rscript -e "print(version)" \
    # TODO: This and the separate install line should be removed eventually. See: https://github.com/numpy/numpy/issues/26710 \
    && apt-get remove -y --purge python3-numpy \
    # TODO: remove fixed zarr version when anndata/conga support zarr v3, including anndata-compat: https://github.com/scverse/anndata/issues/1817
 	&& python3 -m pip install --upgrade "zarr<3.0.0" \
    && python3 -m pip install --upgrade anndata \
    ## NOTE: this is due to: https://github.com/zarr-developers/zarr-python/issues/2963 \
    && python3 -m pip install numcodecs==0.15.1 \
    # NOTE: this is done to ensure we have igraph 0.7.0, see: https://github.com/TomKellyGenetics/leiden
    && python3 -m pip uninstall igraph \
    && python3 -m pip install umap-learn phate scanpy sctour scikit-misc celltypist scikit-learn leidenalg python-igraph \
    # Install conga:
    && mkdir /conga \
    && cd /conga \
    && git clone https://github.com/phbradley/conga.git \
    && cd conga/tcrdist_cpp \
    && make \
    && cd ../ \
    && python3 -m pip install -e . \
    && cd / \
    ##  Add Bioconductor system dependencies
    && export BC_BRANCH=`echo $R_BIOC_VERSION | sed 's/\./_/'` \
    && mkdir /bioconductor && cd /bioconductor \
    && wget -O install_bioc_sysdeps.sh https://raw.githubusercontent.com/Bioconductor/bioconductor_docker/RELEASE_${BC_BRANCH}/bioc_scripts/install_bioc_sysdeps.sh \
    && bash ./install_bioc_sysdeps.sh $R_BIOC_VERSION \
    && cd / \
    && rm -Rf /bioconductor \
    # For SDA, see: https://jmarchini.org/software/
    && wget -O /bin/sda_static_linux https://www.dropbox.com/sh/chek4jkr28qnbrj/AADPy1qQlm3jsHPmPdNsjSx2a/bin/sda_static_linux?dl=1 \
    && chmod +x /bin/sda_static_linux \
    && python3 -m pip install demuxEM \
    # NOTE: switch back to main GMM_demux repo when this is resolved: https://github.com/CHPGenetics/GMM-Demux/pull/8
    && python3 -m pip install git+https://github.com/bbimber/GMM-Demux \
    # Clean up:
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m pip cache purge \
	&& rm -rf /tmp/downloaded_packages/ /tmp/*.rds \
    && mkdir /BiocFileCache && chmod 777 /BiocFileCache \
    && mkdir /dockerHomeDir && chmod 777 /dockerHomeDir \
    # This is to avoid the numba 'cannot cache function' error, such as: https://github.com/numba/numba/issues/5566
    && mkdir /numba_cache && chmod -R 777 /numba_cache \
    && mkdir /mpl_cache && chmod -R 777 /mpl_cache \
    && mkdir /inkscape && chmod -R 777 /inkscape \
    # This is debugging related to numpy/pandas incompatibility:
    && python3 -c "import numpy; print(numpy.__version__)" \
    && python3 -c "import pandas; print(pandas.__version__)"

ENV RETICULATE_PYTHON=/usr/bin/python3

# NOTE: this is required when running as non-root. Setting MPLCONFIGDIR removes a similar warning.
ENV NUMBA_CACHE_DIR=/numba_cache
ENV MPLCONFIGDIR=/mpl_cache

ENV CONGA_PNG_TO_SVG_UTILITY=inkscape
ENV INKSCAPE_PROFILE_DIR=/inkscape
ENV USE_GMMDEMUX_SEED=1

# Create location for BioConductor AnnotationHub/ExperimentHub caches:
ENV ANNOTATION_HUB_CACHE=/BiocFileCache
ENV EXPERIMENT_HUB_CACHE=/BiocFileCache
ENV BFC_CACHE=/BiocFileCache

ENV CELLTYPIST_FOLDER=/tmp

# NOTE: this is also added to support running as non-root. celltypist needs to write in ~/. This might be superceded by CELLTYPIST_FOLDER
#RUN mkdir /userHome && chmod -R 777 /userHome
#ENV HOME=/userHome

# Added for podman support:
ENTRYPOINT ["/bin/bash"]

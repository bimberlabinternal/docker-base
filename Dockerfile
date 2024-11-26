# Note: this is the last base version supporting ubuntu focal, not jammy
FROM rocker/rstudio:latest

ARG GH_PAT='NOT_SET'

# NOTE: inkscape and librsvg2-bin installed for CoNGA
# NOTE: locales / locales-all added due to errors with install_deps() and special characters in the DESCRIPTION file for niaid/dsb
# NOTE: libgdal-dev and 'sf' added due to: https://github.com/r-spatial/sf/issues/2436
RUN echo "local({r <- getOption('repos') ;r['CRAN'] = 'https://packagemanager.rstudio.com/cran/__linux__/focal/latest';options(repos = r);rm(r)})" >> ~/.Rprofile \
    && apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y \
        libhdf5-dev \
        python3-full \
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
    # This avoids the 'error: externally-managed-environment' issue
    && rm -Rf /usr/lib/python3.12/EXTERNALLY-MANAGED \
    && Rscript -e "install.packages(c('remotes', 'devtools', 'BiocManager', 'pryr', 'rmdformats', 'knitr', 'logger', 'Matrix'), dependencies=TRUE, ask = FALSE, upgrade = 'always')" \
    # NOTE: added to fix issues with sf package. Can probably be dropped once we migrate to a non-github version
    && apt-get install -y libudunits2-dev libgdal-dev libgeos-dev libproj-dev \
    && Rscript -e "remotes::install_github('r-spatial/sf')" \
    # TODO: this is to fix the as_cholmod_sparse' not provided by package 'Matrix' errors. This should ultimately be removed
    && Rscript -e "install.packages('irlba', type='source', force=TRUE)" \
    && echo "local({options(repos = BiocManager::repositories('https://packagemanager.rstudio.com/cran/__linux__/focal/latest'))})" >> ~/.Rprofile \
    # NOTE: this was added to avoid the build dying if this downloads a binary built on a later R version
    && echo "Sys.setenv(R_REMOTES_NO_ERRORS_FROM_WARNINGS='true');" >> ~/.Rprofile \
    && Rscript -e "print(version)" \
    && python3 -m pip install --upgrade pip \
    # TODO: added numpy<2 to side-step a numpy version issue. This should be removed eventually. See: https://github.com/numpy/numpy/issues/26710
    && python3 -m pip install "numpy<2.0.0" \
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
    && pip3 install -e . \
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
    # NOTE: switch back to main GMM_demux repo when this is resolved: https://github.com/CHPGenetics/GMM-Demux/pull/8
    # NOTE: switch back to main demuxEM repo when this is resolved: https://github.com/lilab-bcb/demuxEM/pull/16
    && pip3 install git+https://github.com/bbimber/demuxEM.git \
    && pip3 install git+https://github.com/bbimber/GMM-Demux \
    # Clean up:
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 cache purge \
	&& rm -rf /tmp/downloaded_packages/ /tmp/*.rds \
    && mkdir /BiocFileCache && chmod 777 /BiocFileCache \
    && mkdir /dockerHomeDir && chmod 777 /dockerHomeDir \
    # This is to avoid the numba 'cannot cache function' error, such as: https://github.com/numba/numba/issues/5566
    && mkdir /numba_cache && chmod -R 777 /numba_cache \
    && mkdir /mpl_cache && chmod -R 777 /mpl_cache \
    && mkdir /inkscape && chmod -R 777 /inkscape

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

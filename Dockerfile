# Note: this is the last base version supporting ubuntu focal, not jammy
FROM rocker/rstudio:4.2.1

ARG GH_PAT='NOT_SET'

## Redo the R installation, since we need a base image using focal, but updated R version:
# This should be removed in favor of choosing a better base image once Exacloud supports jammy
ENV R_VERSION=4.4.0
ENV R_BIOC_VERSION=3.19
ENV CRAN=https://packagemanager.posit.co/cran/__linux__/focal/latest
RUN /bin/sh -c /rocker_scripts/install_R_source.sh \
  && /bin/sh -c /rocker_scripts/setup_R.sh

# NOTE: inkscape and librsvg2-bin installed for CoNGA
# NOTE: locales / locales-all added due to errors with install_deps() and special characters in the DESCRIPTION file for niaid/dsb
RUN echo "local({r <- getOption('repos') ;r['CRAN'] = 'https://packagemanager.rstudio.com/cran/__linux__/focal/latest';options(repos = r);rm(r)})" >> ~/.Rprofile \
    && Rscript -e "install.packages(c('remotes', 'devtools', 'BiocManager', 'pryr', 'rmdformats', 'knitr', 'logger', 'Matrix', 'sf'), dependencies=TRUE, ask = FALSE, upgrade = 'always')" \
    # TODO: this is to fix the as_cholmod_sparse' not provided by package 'Matrix' errors. This should ultimately be removed
    && Rscript -e "install.packages('irlba', type='source', force=TRUE)" \
	&& echo "local({options(repos = BiocManager::repositories('https://packagemanager.rstudio.com/cran/__linux__/focal/latest'))})" >> ~/.Rprofile \
	# NOTE: this was added to avoid the build dying if this downloads a binary built on a later R version
	&& echo "Sys.setenv(R_REMOTES_NO_ERRORS_FROM_WARNINGS='true');" >> ~/.Rprofile \
    && Rscript -e "print(version)" \
    && apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y \
        libhdf5-dev \
        libpython3-dev \
        python3-pip \
        inkscape \
        librsvg2-bin \
        locales \
        locales-all \
        wget \
        git \
        libxml2-dev \
        libxslt-dev \
    && python3 -m pip install --upgrade pip \
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

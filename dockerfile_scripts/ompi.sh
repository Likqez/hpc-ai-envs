#!/bin/bash

set -x

OMPI_CONFIG_OPTIONS_VAR="--prefix ${HPC_DIR} --enable-prte-prefix-by-default \
   --enable-shared --with-cma --with-pic --with-libfabric=${HPC_DIR}         \
   --without-ucx --with-pmix=internal "

# Install OMPI
OMPI_VER=v5.0
OMPI_VER_NUM=5.0.8
OMPI_CONFIG_OPTIONS=${OMPI_CONFIG_OPTIONS_VAR}
OMPI_SRC_DIR=/tmp/openmpi-src
OMPI_BASE_URL="https://download.open-mpi.org/release/open-mpi"
OMPI_URL="${OMPI_BASE_URL}/${OMPI_VER}/openmpi-${OMPI_VER_NUM}.tar.gz"

mkdir -p ${OMPI_SRC_DIR}                        && \
  cd ${OMPI_SRC_DIR}                            && \
  wget ${OMPI_URL}                              && \
  tar -xzf openmpi-${OMPI_VER_NUM}.tar.gz       && \
  cd openmpi-${OMPI_VER_NUM}                    && \
  ./configure ${OMPI_CONFIG_OPTIONS}            && \
  make                                          && \
  make install                                  && \
  cd /tmp                                       && \
  rm -rf ${OMPI_SRC_DIR}

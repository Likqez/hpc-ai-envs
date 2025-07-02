ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG SCRIPT_DIR=/tmp/dockerfile_scripts
RUN mkdir -p ${SCRIPT_DIR}

# Put all HPC related tools we build under /container/hpc so we can
# have a shared include, lib, bin, etc to simplify our paths and build steps.
ARG HPC_DIR=/container/hpc
RUN mkdir -p ${HPC_DIR}/bin && \
    mkdir -p ${HPC_DIR}/lib && \
    mkdir -p ${HPC_DIR}/include && \
    mkdir -p ${HPC_DIR}/share && \
    ln -s ${HPC_DIR}/lib ${HPC_DIR}/lib64 && \
    chmod -R go+rX ${HPC_DIR}
ENV LD_LIBRARY_PATH=$HPC_DIR/lib:$LD_LIBRARY_PATH
ENV PATH=$HPC_DIR/bin:$PATH

# Setup some default env variables. This is for the end user as well
# as tools we will build since we put include files under HPC_DIR.
COPY dockerfile_scripts/setup_sh_env.sh ${SCRIPT_DIR}
RUN ${SCRIPT_DIR}/setup_sh_env.sh

# We run this here even though it might be a repeat from the base image
# to make sure we have the required bits for building NCCL, libcxi, etc.
COPY dockerfile_scripts/install_deb_packages.sh ${SCRIPT_DIR}
RUN ${SCRIPT_DIR}/install_deb_packages.sh

# Create a symlink for python3 to /usr/local/bin/python
RUN ln -s $(which python3) /usr/local/bin/python

# Should we just use /container as the install dir and put
# everything (ie, ucx/ofi/ompi/mpich) under /container/{bin|lib}
# to clean up these arguments?
# Install Cray CXI headers/lib
COPY dockerfile_scripts/cray-libs.sh ${SCRIPT_DIR}
RUN ${SCRIPT_DIR}/cray-libs.sh

ENTRYPOINT ["bash"]

RUN rm -r /tmp/*

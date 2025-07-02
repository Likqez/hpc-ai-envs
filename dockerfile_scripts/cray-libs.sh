#!/bin/bash

set -x

# Install Cray libcxi. This requires grabbing the cassini/cxi headers
# and installing them into ${HPC_DIR} so we can compile libcxi.
cray_src_dir=/tmp/cray-libs
mkdir -p $cray_src_dir && \
    cd $cray_src_dir && \
    git clone https://github.com/HewlettPackard/shs-cassini-headers.git && \
    git clone https://github.com/HewlettPackard/shs-cxi-driver.git && \
    git clone https://github.com/HewlettPackard/shs-libcxi.git && \
    git clone https://github.com/HewlettPackard/shs-libfabric.git

# Install the cassini headers
cd $cray_src_dir/shs-cassini-headers && \
    cp -r include ${HPC_DIR} && \
    cp -r share ${HPC_DIR} && \
    cp -r share/cassini-headers /usr/share && \
    cp -r share/cassini-headers ${HPC_DIR}/share && \
    cd ../


# Install the cxi-driver headers
cd $cray_src_dir/shs-cxi-driver && \
    cp -r include ${HPC_DIR} && \
    cp include/linux/cxi.h ${HPC_DIR}/include && \
    cd ../
    
# Build libcxi. Note that this will install into ${HPC_DIR} by default,
# which is what we want so that libfabric/ompi/aws can easily find it.
# gt-prototype is still running on 12.0

shs_version=shs-12.0
shs_libcxi_branch=release/$shs_version

#cxi_cflags="-Wno-unused-variable -Wno-unused-but-set-variable -g -O0" 
#cxi_cppflags="-Wno-unused-variable -Wno-unused-but-set-variable -g -O0"
cxi_cflags="-Wno-unused-variable -Wno-unused-but-set-variable -I${HPC_DIR}/include -I${HPC_DIR}/linux -I${HPC_DIR}/uapi" 
cxi_cppflags="-Wno-unused-variable -Wno-unused-but-set-variable -I${HPC_DIR}/include -I${HPC_DIR}/linux -I${HPC_DIR}/uapi"
cd $cray_src_dir/shs-libcxi && \
    git checkout -b $shs_libcxi_branch && \
    ./autogen.sh && \
    ./configure --prefix=${HPC_DIR} \
		CFLAGS="${cxi_cflags}" CPPFLAGS="${cxi_cppflags}" && \
    make -j && \
    make install && \
    cd ../

# Build and install libfabric. Note that this should see the cxi bits
# and enable cxi support. It should also install into ${HPC_DIR} so that
# it is easier for ompi/aws to find it.
cray_ofi_config_opts="--prefix=${HPC_DIR} --with-cassini-headers=${HPC_DIR} --with-cxi-uapi-headers=${HPC_DIR} --enable-cxi=${HPC_DIR} --enable-gdrcopy-dlopen --disable-verbs --disable-efa --enable-lnx --enable-shm"
#ofi_cflags="-Wno-unused-variable -Wno-unused-but-set-variable -g -O0"
#ofi_cppflags="-Wno-unused-variable -Wno-unused-but-set-variable -g -O0"
ofi_cflags="-Wno-unused-variable -Wno-unused-but-set-variable -I${HPC_DIR}/include -I${HPC_DIR}/linux -I${HPC_DIR}/uapi" 
ofi_cppflags="-Wno-unused-variable -Wno-unused-but-set-variable -I${HPC_DIR}/include -I${HPC_DIR}/linux -I${HPC_DIR}/uapi"

## Building from the Libfabric main branch

LIBFABRIC_BASE_URL="https://github.com/ofiwg/libfabric.git"
LIBFABRIC_BRANCH="main"

cd $cray_src_dir                             && \
    git clone ${LIBFABRIC_BASE_URL}          && \
    cd libfabric                             && \
    git checkout ${LIBFABRIC_BRANCH}         && \
    ./autogen.sh                             && \
    ./configure CFLAGS="${ofi_cflags}"          \
        CPPFLAGS="${ofi_cppflags}"              \
	$cray_ofi_config_opts                      && \
    make -j                                  && \
    make install                             && \
    cd ../

# Clean up our git repos used to build cxi/libfabric
rm -rf $cray_src_dir

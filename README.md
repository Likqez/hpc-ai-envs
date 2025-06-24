# HPC 

The following describes how to build Docker containers for PyTorch/TF
that target Cray EX HPC systems with NVIDIA or AMD GPUs and the
SlingShot (SS) interconnect and enable optimal use of the SS network
for NCCL/RCCL/MPI. The NCCL/RCCL support leverage the AWS OFI NCCL
plugin. It is intended that the Docker containers built using this
repository are converted to a Singularity/Apptainer container and
executed via a work load manager (WLM) such as Slurm on the HPC
system.

The images created by this repository use either the NGC or AMD InfinityHub
images as their base and then add the required bits for enabling SS support.
The SS support means installing a new version of OMPI/MPICH that can use
libfabric, Horovod targeting the given OMPI/MPICH, and the AWS OFI NCCL
plugin to enable NCCL/RCCL over libfabric.

Optionally, the build command can be given a pointer to a local
directory that contains copies of the Cray lib{fabric*|cxi*} required to
optimally use the Cray SS network. These libraries can be built into
the docker image to make it easier for users to run their applications
that leverage the SS network. Note that this is optional. If the user
does not specify this directory for the build step then the proper
directories containing the Cray lib{fabric*|cxi*} can be provided at
container runtime. In this case, the libraries will be bind-mounted
into the container at runtime at a known location and the entrypoint
script included in the container will update the LD_LIBRARY_PATH to
utilize these libraries and enable optimal SS performance. Examples of how
to specify the Cray lib{fabric*|cxi*} at runtime are provided below.

## Prerequisites

* Docker or podman
    - Used to build the docker images
* Singularity/Apptainer
    - Used to convert the docker image to a Singularity/Apptainer sif and
      run the application

If Singularity/Apptainer are not available on the system, it can be
installed by a normal user using the following:

```
$> curl -s https://raw.githubusercontent.com/apptainer/apptainer/main/tools/install-unprivileged.sh |  bash -s - install-dir
```

After `apptainer` is installed it can be executed by adding
`install-dir/bin` to the `PATH`. For more information see the
following `apptainer` documentation where it discusses doing an
unprivileged install:

https://apptainer.org/docs/admin/main/installation.html


## Building Images

The build process expects to find `docker` in the default `PATH`. If
`docker` is not installed on the system, it is also sufficient to have
`podman` installed and simply make a symbolic link to `podman` that is
named `docker`. For example:

```
$> ln -s `which podman` $HOME/bin/docker
```

After cloning this repository and ensuring `docker` exists in the
default `PATH`, an image can be built by running `make` on for the
desired target. For example, to build the latest PyTorch image using
the NGC base image, a command similar to the following could be used:

```
$> make >& buildout.txt
```

If successful you should see the resulting docker image:

```
$> docker images | grep hpc
```

By default, the build will include MPI and OFI for targeting the Cray
HPC system. This can be disabled by specifying WITH_MPI=0 and
WITH_OFI=0 to `make`.

### Slingshot Support

By default, the build will clone the required libraries for enabling
support for the Slingshot network, including the Cray `libcxi` and
`libfabric` libraries. The GitHub repositories are cloned and built inside
the container to ensure proper version matching with required libraries.
Further, by building these libraries into the container, there should be
no need to pull in (ie, bind-mount) these or other libraries from the
host Cray system in order to optimally use the SS network.


Once the Docker image is built you can convert it to a Singularity/Apptainer
image using commands similar to the following:

```
$> docker save -o pytorch-ngc-hpc-dev-ss-053a634.tar cray/pytorch-ngc-hpc-dev-ss:053a634
$> singularity build pytorch-ngc-hpc-dev-ss-053a634.sif docker-archive:/path/to/docker/tarball/pytorch-ngc-hpc-dev-ss-053a634.tar
```

## Examples

### MPI OSU Benchmarks

The following is an example of how to test MPI to verify that the
MPI inside the container can correctly use the Cray libfabric/cxi. Note that
the container used in this example pulled in copies of the Cray libfabric/cxi
as part of the final build step (ie, Dockerfile-ss) so the command does
not bind-mount in the Cray libfabric/cxi at container runtime.

```
$> wget https://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-7.4.tar.gz
$> tar zxf osu-micro-benchmarks-7.4.tar.gz
$> cd osu-micro-benchmarks-7.4/
$> singularity shell --nv --bind $TMPDIR --bind `pwd` /projects/benchmarking/public/sif/cray-pytorch-ngc-hpc-dev.sif
Singularity>  ./configure CC=`which mpicc` CXX=`which mpicxx` --prefix=`pwd`
Singularity> make
Singularity> exit
$> srun --exclusive -c 72 --distribution=*:block --mpi=pmi2 -n 2 --ntasks-per-node=1 --cpu-bind=socket --ntasks-per-socket=1 --sockets-per-node=4 --gpus=8 singularity run --nv --bind /projects --bind $TMPDIR --bind $HOME --bind `pwd` /projects/benchmarking/public/sif/cray-pytorch-ngc-hpc-dev.sif /projects/benchmarking/public/examples/wrapper.sh ./c/mpi/one-sided/osu_get_bw
```

This should produce output similar to:

```
# OSU MPI_Get Bandwidth Test v7.4
# Window creation: MPI_Win_allocate
# Synchronization: MPI_Win_flush
# Datatype: MPI_CHAR.
# Size      Bandwidth (MB/s)
1                       1.03
2                       2.10
4                       4.20
8                       8.38
16                     16.78
32                     33.57
64                     65.82
128                   132.22
256                   254.89
512                   510.63
1024                 1019.58
2048                 2036.45
4096                 4045.65
8192                 7563.77
16384               11773.70
32768               15233.84
65536               18976.11
131072              21131.24
262144              22495.07
524288              23224.79
1048576             23590.77
2097152             23807.66
4194304             23903.40
```


### Notes

A common requirement for each of these tests that use these
Singularity containers is that the Cray libfabric/cxi need to be made
available to the container when running. This is done by the following
bind mount option to the singularity run commands:

```
--bind /opt/cray/libfabric/1.15.2.0/lib64:/host/lib,/usr:/host/usr
```

The destination mount points of `/host/lib` and `/host/usr` are
important because these are the locations where the container
entrypoint script will look for the Cray libfabric/cxi in order to
automatically swap them in place of the open-source libfabric built
into the container. This is what is needed to enable SS11 to be
utilized by NCCL inside of the container.


This repository is based off the following branch of the Determined-AI
task environments repository:

https://github.com/determined-ai/environments/tree/cleanup-hpc-build



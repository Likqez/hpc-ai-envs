# HPC 

The following describes how to build Docker containers
that target Cray EX HPC systems with the  SlingShot (SS) interconnect 
and enable optimal use of the SS network It is intended that the Docker
containers built using this repository are converted to a
Singularity/Apptainer container and executed via a work load manager (WLM)
such as Slurm on the HPC system.

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

### CXI Latency Benchmarks
```shell
srun --nodelist=gtnode19 --exclusive --ntasks=1 singularity exec 3.13.5-slim-bookworm-hpc-84193c9.sif cxi_write_lat > /dev/null 2>&1
srun --nodelist=gtnode20 --exclusive --ntasks=1 singularity exec 3.13.5-slim-bookworm-hpc-84193c9.sif cxi_write_lat gtnode19

srun --nodelist=gtnode19 --exclusive --ntasks=1 singularity exec 3.13.5-slim-bookworm-hpc-84193c9.sif cxi_read_lat > /dev/null 2>&1
srun --nodelist=gtnode20 --exclusive --ntasks=1 singularity exec 3.13.5-slim-bookworm-hpc-84193c9.sif cxi_read_lat gtnode19
```
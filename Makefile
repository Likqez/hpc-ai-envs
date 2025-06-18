SHELL := /bin/bash -o pipefail
VERSION := $(shell cat VERSION)
VERSION_DASHES := $(subst .,-,$(VERSION))
SHORT_GIT_HASH := $(shell git rev-parse --short HEAD)

export DOCKERHUB_REGISTRY := cray
export REGISTRY_REPO := hpc-ai-envs
CPU_PREFIX_39 := $(REGISTRY_REPO):py-3.9-
CPU_PREFIX_310 := $(REGISTRY_REPO):py-3.10-

CPU_SUFFIX := -cpu
PLATFORM_LINUX_ARM_64 := linux/arm64
PLATFORM_LINUX_AMD_64 := linux/amd64
BUILD_OPTS ?=

# Default to enabling MPI, OFI and SS11. Note that if we cannot
# find the SS11 libs automatically and the user did not provide
# a location we will not end up building the -ss version of the image.
# This just means the user would need to bind-mount the SS11 libs
# at runtime.
WITH_MPI ?= 1
WITH_OFI ?= 1
WITH_SS11 ?= 0
CRAY_LIBFABRIC_DIR ?= "/opt/cray/libfabric/1.15.2.0"
CRAY_LIBCXI_DIR ?= "/usr"

# If the user doesn't explicitly pass in a value for BUILD_SIF, then
# default it to 1 if singularity is in the PATH
BUILD_SIF ?= $(shell singularity -h 2>/dev/null|head -1c 2>/dev/null|wc -l)

# If the user specifies USE_CWD_SIF=1 on the command line, singularity
# will use the current working directory for temp and cache space, this
# is useful if there's not enough space in /tmp for example.
# If not specified (or if USE_CWD_SIF=0 is set) then singularity will
# use its default tmp and cache dir locations.
USE_CWD_SIF ?= 0

ifeq "$(WITH_MPI)" "1"
	HPC_SUFFIX := -hpc
	PLATFORMS := $(PLATFORM_LINUX_AMD_64),$(PLATFORM_LINUX_ARM_64)
	WITH_AWS_TRACE := 0
	MPI_BUILD_ARG := WITH_MPI=1

	ifeq "$(WITH_OFI)" "1"
		CPU_SUFFIX := -cpu
		OFI_BUILD_ARG := WITH_OFI=1
	else
		CPU_SUFFIX := -cpu
		OFI_BUILD_ARG := WITH_OFI
	endif
else
	PLATFORMS := $(PLATFORM_LINUX_AMD_64),$(PLATFORM_LINUX_ARM_64)
	WITH_MPI := 0
	OFI_BUILD_ARG := WITH_OFI
	MPI_BUILD_ARG := USE_GLOO=1
endif

ifeq "$(WITH_SS11)" "1"
	ifeq ($(HPC_LIBS_DIR),)
           LIBFAB_SO=$(shell find $(CRAY_LIBFABRIC_DIR) -name libfabric\*so.\*)
           LIBCXI_SO=$(shell find $(CRAY_LIBCXI_DIR) -name libcxi\*so.\*)
           # Make sure we found the libs
           ifneq ($(and $(LIBFAB_SO),$(LIBCXI_SO)),)
              LIBFAB_DIR=$(shell dirname $(LIBFAB_SO))
              LIBCXI_DIR=$(shell dirname $(LIBCXI_SO))
              # Copy the libfabric/cxi to a tmp dir for the HPC_LIBS_DIR
              TMP_FILE:=$(shell mktemp -d -t ss11-libs.XXXXXX)
              TMP_FILE_BASE=$(shell basename $(TMP_FILE))
              # Make a tmp dir in the cwd using the tmp_file name.
              # We do this to distinguish if we made the dir vs the user
              # putting it there so we know to clean it up after the build.
              $(shell mkdir $(TMP_FILE_BASE))
              HPC_LIBS_DIR=$(TMP_FILE_BASE)
              cp_out:=$(shell cp $(LIBFAB_DIR)/libfabric* $(HPC_LIBS_DIR))
              cp_out:=$(shell cp $(LIBCXI_DIR)/libcxi* $(HPC_LIBS_DIR))
              # Signal that the libs were copied so we clean them up after.
              HPC_TMP_LIBS_DIR := 1
           endif
        endif
endif

# TODO REPLACE THIS CORRECTLY

BASE_IMAGE_TAG := 3.13.5-slim-bookworm
BASE_IMAGE := docker.io/python:$(BASE_IMAGE_TAG)
OUTPUT_IMAGE :=$(BASE_IMAGE_TAG)-hpc

NGC_PYTORCH_PREFIX := docker.io/python
NGC_PYTORCH_VERSION := 3.13.5-slim-bookworm
NGC_PYTORCH_REPO := ngc-$(NGC_PYTORCH_VERSION)-pt
NGC_PYTORCH_HPC_REPO := $(NGC_PYTORCH_VERSION)-hpc

# build pytorch sif
TMP_SIF := $(shell mktemp -d -t sif-reg.XXXXXX)
TMP_SIF_BASE := "$(PWD)/$(shell basename $(TMP_SIF))"

SING_DIRS :=
ifeq "$(USE_CWD_SIF)" "1"
     SING_DIRS := SINGULARITY_TMPDIR=$(TMP_SIF_BASE) SINGULARITY_CACHEDIR=$(TMP_SIF_BASE)
endif

.PHONY: build-sif
build-sif:
	# Make a tmp dir in the cwd using the tmp_file name.
	mkdir $(TMP_SIF_BASE)
	docker save -o "$(TARGET_NAME).tar" $(TARGET_TAG)
	env $(SING_DIRS) \
            SINGULARITY_NOHTTPS=true NAMESPACE="" \
            singularity -vvv build $(TARGET_NAME).sif \
                             "docker-archive://$(TARGET_NAME).tar"
	rm -rf $(TMP_SIF_BASE) "$(TARGET_NAME).tar"

# build hpc together since hpc is dependent on the normal build
.PHONY: build-hpc
build-hpc:
	#docker build -f Dockerfile-pytorch-ngc $(BUILD_OPTS) \
	#	--build-arg BASE_IMAGE="$(NGC_PYTORCH_PREFIX):$(NGC_PYTORCH_VERSION)" \
	#	-t $(DOCKERHUB_REGISTRY)/$(NGC_PYTORCH_REPO):$(SHORT_GIT_HASH) \
	#	.
	docker build -f Dockerfile-ngc-hpc $(BUILD_OPTS) \
		--build-arg "$(MPI_BUILD_ARG)" \
		--build-arg "$(OFI_BUILD_ARG)" \
		--build-arg "WITH_PT=1" \
		--build-arg "WITH_TF=0" \
		--build-arg BASE_IMAGE="$(BASE_IMAGE)" \
		-t $(DOCKERHUB_REGISTRY)/$(OUTPUT_IMAGE):$(SHORT_GIT_HASH) \
		.
ifneq ($(HPC_LIBS_DIR),)
	@echo "HPC_LIBS_DIR: $(HPC_LIBS_DIR)"
	docker build -f Dockerfile-ss $(BUILD_OPTS) \
		--build-arg BASE_IMAGE=$(DOCKERHUB_REGISTRY)/$(NGC_PYTORCH_HPC_REPO):$(SHORT_GIT_HASH) \
		--build-arg "HPC_LIBS_DIR=$(HPC_LIBS_DIR)" \
		-t $(DOCKERHUB_REGISTRY)/$(NGC_PYTORCH_HPC_REPO)-ss:$(SHORT_GIT_HASH) \
		.
        ifneq ($(HPC_TMP_LIBS_DIR),)
	    rm -rf $(HPC_LIBS_DIR)
        endif
        ifeq "$(BUILD_SIF)" "1"
	    @echo "BUILD_SIF: $(NGC_PYTORCH_HPC_REPO)-ss:$(SHORT_GIT_HASH)"
	    make build-sif TARGET_TAG="$(DOCKERHUB_REGISTRY)/$(NGC_PYTORCH_HPC_REPO)-ss:$(SHORT_GIT_HASH)" \
                          TARGET_NAME="$(NGC_PYTORCH_HPC_REPO)-$(SHORT_GIT_HASH)"
        endif
else
        ifeq "$(BUILD_SIF)" "1"
	    @echo "BUILD_SIF: $(NGC_PYTORCH_HPC_REPO):$(SHORT_GIT_HASH)"
	    make build-sif TARGET_TAG="$(DOCKERHUB_REGISTRY)/$(NGC_PYTORCH_HPC_REPO):$(SHORT_GIT_HASH)" \
                          TARGET_NAME="$(NGC_PYTORCH_HPC_REPO)-$(SHORT_GIT_HASH)"
        endif
endif
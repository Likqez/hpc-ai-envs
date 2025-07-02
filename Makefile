SHELL := /bin/bash -o pipefail
SHORT_GIT_HASH := $(shell git rev-parse --short HEAD)

export DOCKERHUB_REGISTRY := trcm

# Default to enabling MPI
WITH_MPI ?= 1

# If the user doesn't explicitly pass in a value for BUILD_SIF, then
# default it to 1 if singularity is in the PATH
BUILD_SIF ?= $(shell singularity -h 2>/dev/null|head -1c 2>/dev/null|wc -l)

# If the user specifies USE_CWD_SIF=1 on the command line, singularity
# will use the current working directory for temp and cache space, this
# is useful if there's not enough space in /tmp for example.
# If not specified (or if USE_CWD_SIF=0 is set) then singularity will
# use its default tmp and cache dir locations.
USE_CWD_SIF ?= 0

BASE_IMAGE_TAG := 22.04
BASE_IMAGE := docker.io/ubuntu:$(BASE_IMAGE_TAG)
OUTPUT_IMAGE :=$(DOCKERHUB_REGISTRY)/$(BASE_IMAGE_TAG)-hpc-$(SHORT_GIT_HASH)

# build sif
TMP_SIF := $(shell mktemp -d -t sif-reg.XXXXXX)
TMP_SIF_BASE := "$(PWD)/$(shell basename $(TMP_SIF))"

ifeq "$(USE_CWD_SIF)" "1"
     SING_DIRS := SINGULARITY_TMPDIR=$(TMP_SIF_BASE) SINGULARITY_CACHEDIR=$(TMP_SIF_BASE)
endif

.PHONY: all
all: build-hpc

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

# build hpc
.PHONY: build-hpc
build-hpc:
	docker build -f Dockerfile \
		--build-arg BASE_IMAGE="$(BASE_IMAGE)" \
		-t $(OUTPUT_IMAGE) \
		.
SHELL := /bin/bash -o pipefail
SHORT_GIT_HASH := $(shell git rev-parse --short HEAD)

export DOCKERHUB_REGISTRY := trcm

BASE_IMAGE_TAG := 3.13.5-slim-bookworm
BASE_IMAGE := docker.io/python:$(BASE_IMAGE_TAG)
OUTPUT_IMAGE :=$(DOCKERHUB_REGISTRY)/$(BASE_IMAGE_TAG)-hpc-$(SHORT_GIT_HASH)

.PHONY: all
all: build-hpc

# build hpc
.PHONY: build-hpc
build-hpc:
	docker build -f Dockerfile \
		--build-arg BASE_IMAGE="$(BASE_IMAGE)" \
		-t $(OUTPUT_IMAGE) \
		.